#!/usr/bin/env bash
# Calcula la version semver automatica segun la rama (ver docs/gitflow-v2.png).
#
# Uso: semver.sh <branch> [version.json]
# Requiere: git con tags y ramas descargados (fetch-depth: 0), jq.
# Salida (key=value; a $GITHUB_OUTPUT si existe y siempre a stdout):
#   kind         feature | prerelease | rc | release | noop
#   version      X.Y.Z
#   tag          tag git (vX.Y.Z-prerelease.N | vX.Y.Z-rc.N | vX.Y.Z); vacio en feature/noop
#   image_tag    tag de la imagen docker (= tag sin la "v")
#   rc_tag       solo en main: rc que se promociona (retag, sin rebuild)
#   environment  dev | pre | pro | ''
#
# Reglas de version:
#   develop     X.Y.Z = proxima release, calculada con Conventional Commits desde el ultimo vX.Y.Z estable:
#                 BREAKING (feat!: / BREAKING CHANGE) -> major, feat -> minor, resto -> patch.
#                 version.json actua como suelo (si es mayor, manda).
#   release/*   X.Y.Z = nombre de la rama (release/X.Y.Z, lo crea "Cut release"); si no es semver, se calcula.
#   hotfix/*    X.Y.Z = nombre de la rama (hotfix/X.Y.Z); si no es semver, patch+1 del ultimo estable.
#   main        X.Y.Z del rc mergeado (retag, sin rebuild).
#   N es incremental por (version, tipo): max(N existente)+1.
set -euo pipefail

BRANCH="${1:?uso: semver.sh <branch> [version.json]}"
VERSION_FILE="${2:-version.json}"
SEMVER_RE='^[0-9]+\.[0-9]+\.[0-9]+$'

out() { if [[ -n "${GITHUB_OUTPUT:-}" ]]; then echo "$1=$2" >> "$GITHUB_OUTPUT"; fi; echo "$1=$2"; }

base=$(jq -r '.version' "$VERSION_FILE")
[[ "$base" =~ $SEMVER_RE ]] || { echo "::error::version.json: '$base' no es X.Y.Z"; exit 1; }

# ultimo tag estable (sin "v"); vacio si no hay
latest=$(git tag -l 'v*' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sed 's/^v//' | sort -V | tail -1 || true)

# nivel de bump segun Conventional Commits desde el ultimo estable
bump_level() {
  local range="HEAD"; [[ -n "$latest" ]] && range="v${latest}..HEAD"
  local subjects bodies
  subjects=$(git log --no-merges --format='%s' "$range" 2>/dev/null || true)
  bodies=$(git log --no-merges --format='%b' "$range" 2>/dev/null || true)
  if grep -qE '^[a-z]+(\([^)]*\))?!:' <<< "$subjects" || grep -q '^BREAKING[ -]CHANGE' <<< "$bodies"; then echo major
  elif grep -qE '^feat(\([^)]*\))?:' <<< "$subjects"; then echo minor
  else echo patch; fi
}

bump() { # bump <X.Y.Z> <major|minor|patch>
  local M m p; IFS=. read -r M m p <<< "$1"
  case "$2" in
    major) echo "$((M + 1)).0.0" ;;
    minor) echo "$M.$((m + 1)).0" ;;
    patch) echo "$M.$m.$((p + 1))" ;;
  esac
}

next_release() {
  [[ -n "$latest" ]] || { echo "$base"; return; }
  local calc; calc=$(bump "$latest" "$(bump_level)")
  # version.json es el suelo
  printf '%s\n%s\n' "$base" "$calc" | sort -V | tail -1
}

next_hotfix() {
  [[ -n "$latest" ]] || { echo "::error::hotfix requiere al menos un tag vX.Y.Z estable en main"; exit 1; }
  bump "$latest" patch
}

# siguiente N para v<version>-<suffix>.N
next_n() {
  local version=$1 suffix=$2 max
  max=$(git tag -l "v${version}-${suffix}.*" | sed -E "s/^v${version//./\\.}-${suffix}\.//" | grep -E '^[0-9]+$' | sort -n | tail -1 || true)
  echo $(( ${max:-0} + 1 ))
}

version_from_branch() { # release/1.2.3 -> 1.2.3 ; si no es semver devuelve vacio
  local v="${BRANCH#*/}"; [[ "$v" =~ $SEMVER_RE ]] && echo "$v" || true
}

kind=""; version=""; tag=""; rc_tag=""; env=""

case "$BRANCH" in
  develop)
    kind=prerelease; env=dev
    version=$(next_release); tag="v${version}-prerelease.$(next_n "$version" prerelease)" ;;
  release/*)
    kind=rc; env=pre
    version=$(version_from_branch); [[ -n "$version" ]] || version=$(next_release)
    tag="v${version}-rc.$(next_n "$version" rc)" ;;
  hotfix/*)
    kind=rc; env=pre
    version=$(version_from_branch); [[ -n "$version" ]] || version=$(next_hotfix)
    # rama recien creada desde main, sin commits propios: nada que construir
    if git rev-parse -q --verify origin/main >/dev/null && git merge-base --is-ancestor HEAD origin/main; then
      kind=noop; env=""; tag=""
    else
      tag="v${version}-rc.$(next_n "$version" rc)"
    fi ;;
  main)
    kind=release; env=pro
    # 1) rc alcanzable desde el 2do padre del merge (rama release/hotfix mergeada)
    rc_tag=$(git describe --tags --abbrev=0 --match 'v*-rc.*' HEAD^2 2>/dev/null || true)
    # 2) fallback (squash / fast-forward): mayor rc cuya version aun no tiene tag estable
    if [[ -z "$rc_tag" ]]; then
      cand=""
      for v in $(git tag -l 'v*-rc.*' | sed -E 's/^v([0-9]+\.[0-9]+\.[0-9]+)-rc\..*/\1/' | sort -Vu); do
        git rev-parse -q --verify "refs/tags/v$v" >/dev/null || cand=$v
      done
      [[ -n "$cand" ]] || { echo "::error::main sin ningun rc pendiente de promocionar"; exit 1; }
      rc_tag="v${cand}-rc.$(( $(next_n "$cand" rc) - 1 ))"
    fi
    version=$(echo "$rc_tag" | sed -E 's/^v([0-9]+\.[0-9]+\.[0-9]+)-rc\..*/\1/')
    tag="v${version}" ;;
  *)
    kind=feature ;;   # feature/*, PRs y cualquier otra: solo tests + sonar, sin tag
esac

out kind "$kind"; out version "$version"; out tag "$tag"; out image_tag "${tag#v}"
out rc_tag "$rc_tag"; out environment "$env"
