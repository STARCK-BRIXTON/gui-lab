# lab-mode: laboratorio GitFlow + SemVer automatico

Workflow dummy (`.github/workflows/gitflow.cicd.yaml`) que reproduce `gitflow.png`. Todos los steps (tests, Sonar, build, push, deploy) son `echo`; lo real es el versionado, el tageo y la sincronizacion de ramas.

## Version
- `version.json` -> version **base** (`X.Y.Z`). Solo se toca para saltar de major/minor a mano.
- `.github/scripts/semver.sh` calcula todo lo demas a partir de los tags existentes.

| Rama | Tag | Version |
|---|---|---|
| `develop` | `vX.Y.Z-prerelease.N` | proxima release (ultimo stable con minor+1, o `version.json` si es mayor) |
| `release/*` | `vX.Y.Z-rc.N` | idem |
| `hotfix/*` | `vX.Y.(Z+1)-rc.N` | patch+1 del ultimo stable |
| `main` | `vX.Y.Z` + GitHub Release | la del rc mergeado, **retag sin rebuild** |
| `feature/*`, PRs | sin tag | solo unit tests + sonar |

`N` es incremental por version y tipo. Primer ciclo con la base `1.0.0`: `v1.0.0-prerelease.1..n` -> `v1.0.0-rc.1..n` -> `v1.0.0` -> develop pasa a `1.1.0-prerelease.1`.

## Flujo
`feature -> PR develop` (test+sonar) -> `develop` (test, sonar, build, tag prerelease, deploy dev) -> `release/*` desde develop (build, tag rc, publish, deploy pre) -> PR a `main` -> retag + tag estable + deploy `pro` (aprobacion) -> **merge main -> develop** solo si Deploy PRO fue OK (directo; si hay conflicto o rama protegida, abre PR `sync/main-vX.Y.Z`) y re-dispara develop.
Hotfix: `hotfix/*` desde `main` -> rc en pre -> PR a main -> mismo camino.

## Setup en GitHub
1. Crear rama `develop` y `main`.
2. Settings > Environments: crear `dev`, `pre`, `pro`; en `pro` activar **Required reviewers** (gated approval).
3. Settings > Actions > General: *Workflow permissions* = read and write, y permitir que Actions cree PRs.
4. **Mergear a `main` con merge commit** (no squash): asi se detecta el rc exacto via el 2do padre. Con squash hay un fallback (mayor rc sin release), valido si solo hay un rc pendiente.

## Pruebas sugeridas
1. `feature/a` -> PR a develop: solo checks. Merge -> `v1.0.0-prerelease.1`. Otro merge -> `.2`.
2. `release/1.0.0` desde develop: push -> `v1.0.0-rc.1`; otro push -> `rc.2`.
3. PR release -> main (merge commit): retag `v1.0.0`, aprobar `pro`, ver sync a develop y `v1.1.0-prerelease.1`.
4. `hotfix/fix` desde main: `v1.0.1-rc.1` -> PR a main -> `v1.0.1` -> sync.
5. Fallo en PRO: Run workflow en `main` con `fail_pro_deploy=true` -> no debe correr el sync.
6. Cambiar `version.json` a `2.0.0` en develop -> proximo prerelease `v2.0.0-prerelease.1`.

Probar el calculo en local: `.github/scripts/semver.sh develop version.json` (requiere `jq` y tags).

## Limitaciones conocidas
- Los pushes hechos con `GITHUB_TOKEN` no disparan workflows (por eso el sync re-lanza develop con `workflow_dispatch`).
- Si hay un release y un hotfix pendientes a la vez, el fallback sin merge commit toma el rc de mayor version.
