# gui-lab: laboratorio GitFlow + SemVer automático

Pipeline dummy que reproduce [docs/gitflow-v2.png](docs/gitflow-v2.png). Docker/ACR/AKS/Helm/Sonar son `echo`; lo real es el versionado, el tageo, el PR automático y la sincronización de ramas.

## El usuario solo toca 3 cosas
1. Mergear PRs de `feature/*` a `develop` (**squash**, título Conventional Commits).
2. Pulsar **Actions → Cut release** cuando quiera sacar versión (o **Cut hotfix**).
3. Mergear el PR a `main` que abre el pipeline (**merge commit**) y **aprobar** el deploy a `pro`.

## Versionado (`.github/scripts/semver.sh`)
| Rama | Tag git | Imagen docker | Entorno |
|---|---|---|---|
| `develop` | `vX.Y.Z-prerelease.N` | `X.Y.Z-prerelease.N` | dev |
| `release/X.Y.Z` | `vX.Y.Z-rc.N` | `X.Y.Z-rc.N` | pre |
| `hotfix/X.Y.Z` | `vX.Y.Z-rc.N` | `X.Y.Z-rc.N` | pre |
| `main` | `vX.Y.Z` + Release (**tras Deploy PRO OK**) | retag de la imagen rc (sin rebuild) | pre → pro |
| `feature/*`, PR | — | — | solo tests + sonar |

- **X.Y.Z en develop** sale de Conventional Commits desde el último `vX.Y.Z`: `feat!:`/`BREAKING CHANGE` → major, `feat:` → minor, resto → patch. `version.json` es el **suelo**: si es mayor, manda (sirve para forzar un salto).
- **release/hotfix**: la versión es el nombre de la rama (lo crean los botones, así rama y tag siempre coinciden).
- `N` es incremental por versión y tipo.
- Un `hotfix/*` recién creado (sin commits propios) no construye nada (`noop`).

## Flujo
`feature` → PR a develop (título válido, tests, sonar) → `develop` (tests, sonar, build+push imagen, tag prerelease, deploy dev) → **Cut release** → `release/X.Y.Z` (build+push `X.Y.Z-rc.N`, tag, deploy pre, **PR automático a main** si pre OK) → merge → `main` (retag, deploy pre `X.Y.Z`, **aprobación**, deploy pro, tag+Release, **sync main → develop**).
Hotfix: **Cut hotfix** → pushear el fix a `hotfix/X.Y.Z` → mismo camino desde el rc.

## Workflows
| Archivo | Qué hace |
|---|---|
| `gitflow.cicd.yaml` | pipeline principal |
| `cut-release.yaml` | botón: crea `release/X.Y.Z` desde develop (falla si ya hay una release abierta) |
| `cut-hotfix.yaml` | botón: crea `hotfix/X.Y.(Z+1)` desde main |
| `pr-title.yaml` | exige Conventional Commits en el título de PRs a develop |

## Setup en GitHub
1. Ramas `main` y `develop`. Dejar un primer commit en `main` y partir `develop` de ahí.
2. Settings → Environments: `dev`, `pre`, `pro` (en `pro` activar **Required reviewers**).
3. Settings → Actions → General: *Workflow permissions* = read and write + *Allow GitHub Actions to create and approve pull requests*.
4. Settings → General → Pull Requests: squash merge con *Default to pull request title*.
5. (Recomendado) secret `GITFLOW_TOKEN` (PAT o GitHub App con contents/pull-requests/workflows): con él los pushes del pipeline disparan workflows. Sin él se usa `GITHUB_TOKEN` y el pipeline re-dispara con `workflow_dispatch`.

## Pruebas sugeridas
1. `feature/a` con `feat: algo` → PR a develop (título inválido debe fallar) → merge → `v1.0.0-prerelease.1`.
2. **Cut release** → `release/1.0.0` → `v1.0.0-rc.1`, deploy pre, PR a main abierto solo.
3. Cortar otra release con una abierta → debe fallar. Pushear un fix a `release/1.0.0` → `rc.2`.
4. Mergear el PR (merge commit) → retag, deploy pre, aprobar `pro` → tag/Release `v1.0.0` → sync → `develop` genera `v1.0.1-prerelease.1` (o `v1.1.0` si hubo `feat:`).
5. **Cut hotfix** → `hotfix/1.0.1` (noop) → pushear `fix:` → `v1.0.1-rc.1` → PR → `v1.0.1`.
6. Fallo en PRO: *Run workflow* en `main` con `fail_pro_deploy=true` → sin tag/Release ni sync.
7. Subir `version.json` a `2.0.0` en develop → `v2.0.0-prerelease.1`.

## Limitaciones
- Si hay release y hotfix pendientes a la vez y se mergea con squash, el fallback toma el rc de mayor versión. Usar merge commit.
- Tras un hotfix, una `release/*` abierta no recibe el cambio automáticamente (solo develop).
- Probar el cálculo en local: `.github/scripts/semver.sh develop version.json` (requiere `jq` y tags).
