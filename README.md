# gui-lab: laboratorio GitFlow + SemVer automático (v3)

Pipeline dummy que reproduce [docs/gitflow-v3.png](docs/gitflow-v3.png). Docker/ACR/AKS/Helm/Sonar/Anchore son `echo`; lo real es el versionado, el tageo, la promoción y la sincronización de ramas.

**Reglas clave**
- `main` = lo que está desplegado en PRO (el merge a `main` ocurre solo tras un deploy OK).
- Una imagen por commit: `prerelease.N`, `rc.N` y `X.Y.Z` son tags del **mismo digest** (clone, nunca rebuild).
- **Tag rc = commit validado en PRE.** Se crea solo tras el deploy a PRE OK.
- PRE se **congela** mientras haya `release/*` o `hotfix/*` abierto (develop sigue a DEV, pero no pisa PRE).

## El usuario solo toca 3 cosas
1. PRs a `develop` con título Conventional Commits (`feat:`, `fix:`, `feat!:`), squash merge.
2. Botón **Release** (Actions → Release) y **aprobar** el environment `pro`.
3. Hotfix: botón **Hotfix**, pushear el fix y **aprobar** `pro`.

## Versionado (`.github/scripts/semver.sh`)
- `develop`: `X.Y.Z` = último `vX.Y.Z` + bump por commits (`feat!`/`BREAKING CHANGE` → major, `feat` → minor, resto → patch). `version.json` es el suelo.
- `N` único y compartido: `vX.Y.Z-prerelease.N` (imagen DEV) y `vX.Y.Z-rc.N` (imagen PRE) usan el mismo N.
- `release/X.Y.Z`, `hotfix/X.Y.Z`: la versión es el nombre de la rama (la crean los botones).

| kind | cuándo | qué hace |
|---|---|---|
| `feature` | feature/*, PRs | tests + sonar |
| `prerelease` | develop | tests, sonar, build, scan, tag prerelease, DEV, clone a PRE, PRE, tag rc |
| `rc` | release/hotfix con commit nuevo (fix) | tests, sonar, build, scan, PRE, tag rc.N+1, luego promueve |
| `promote` | release/hotfix cuyo HEAD ya tiene rc | no construye: promueve a PRO |
| `noop` | main, hotfix recién creado | nada |

## Flujo
`feature` → PR a develop → `develop` (DEV + PRE, tags prerelease.N y rc.N) → botón **Release** corta `release/X.Y.Z` en el **último commit con tag rc** → clone pre→pro `X.Y.Z` → **aprobación** → deploy PRO desde la rama → **solo si OK**: merge a `main` (merge commit), tag `vX.Y.Z` + Release, borra la rama, sync `main → develop` (directo; PR `sync/main-vX.Y.Z` si hay conflicto/protección).
Hotfix: botón **Hotfix** → `hotfix/X.Y.(Z+1)` desde main → pushear el fix → tests + sonar + build + scan → PRE → aprobación → PRO → mismo cierre; además se sincroniza `main` en una `release/*` abierta (se revalida: el commit nuevo no tiene rc).

Si PRO falla: `main`, tag y Release no se tocan y la rama sigue viva. Fallo transitorio → **Re-run failed jobs** (idempotente). Bug → fix en la rama (`rc.N+1`) y se vuelve a promover.

## Workflows
| Archivo | Qué hace |
|---|---|
| `gitflow.cicd.yaml` | pipeline completo: calidad, build, scan, tags, DEV/PRE, promoción a PRO, finalize y syncs |
| `cut-release.yaml` (Release) | botón: crea `release/X.Y.Z` en el último rc validado (falla si ya hay una abierta) |
| `cut-hotfix.yaml` (Hotfix) | botón: crea `hotfix/X.Y.(Z+1)` desde main |
| `pr-title.yaml` | exige Conventional Commits en el título de PRs a develop |

## Setup en GitHub
1. Ramas `main` y `develop`.
2. Environments: `dev`, `pre`, `pro`. En `pro`: **Required reviewers** (gated approval). *Deployment branches*: `pro` solo `release/**` y `hotfix/**`; `pre` solo `develop`, `release/**`, `hotfix/**`; `dev` solo `develop`.
3. Settings → Actions → General: workflow permissions read/write + permitir crear PRs.
4. Squash merge con *Default to pull request title*.
5. Rulesets en `main` y `develop` con bypass para el bot, y status checks requeridos (`pr-title`, tests). Secret `GITFLOW_TOKEN` (GitHub App o PAT con bypass): permite saltar la protección y que los pushes del pipeline disparen workflows. Sin él se usa `GITHUB_TOKEN` y se re-dispara con `workflow_dispatch`.

## Pruebas
- Local: `bash .github/scripts/semver.test.sh` (repo temporal; cubre N compartido, release desde rc, hotfix noop/con fix, bump por commits, `version.json` como suelo).
- En GitHub:
  1. PR con título inválido falla. Merge de `feat:` → `v1.0.0-prerelease.1` + `v1.0.0-rc.1`, DEV y PRE desplegados.
  2. **Release** → `release/1.0.0` en ese rc, sin build; aprobar `pro` → merge a main, `v1.0.0`, Release, rama borrada, sync a develop.
  3. Con una release abierta, un merge a develop **no** toca PRE (queda congelado).
  4. Run workflow en `release/*` con `fail_pro_deploy=true` → `main` intacto, sin tag.
  5. **Hotfix** → `hotfix/1.0.1` (noop) → push de `fix:` → tests, sonar, scan, `v1.0.1-rc.1`, aprobar `pro` → `v1.0.1`, sync a develop y a la release abierta.
  6. `version.json` a `2.0.0` en develop → `v2.0.0-prerelease.1`.

## Limitaciones
- Los jobs de deploy usan `concurrency` por entorno sin cancelar; GitHub conserva solo un job pendiente por grupo (el más reciente).
- Si hay release y hotfix abiertos a la vez y hay conflicto al sincronizar, hay que resolverlo a mano (aviso en el log).
- Regenerar el diagrama: `python3 docs/gen_gitflow_v3.py` y renderizar el SVG con Chrome headless.
