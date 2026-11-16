#!/usr/bin/env bash
# Calcula la version semver automatica segun la rama (ver gitflow.png).
#
# Uso: semver.sh <branch> [version.json]
# Requiere: git con tags descargados (fetch-depth: 0), jq.
# Salida (key=value, a $GITHUB_OUTPUT si existe, si no a stdout):
#   kind       feature | prerelease | rc | release
#   version    X.Y.Z base (sin sufijo)
#   tag        tag git a crear (vX.Y.Z-prerelease.N | vX.Y.Z-rc.N | vX.Y.Z); vacio en feature
#   rc_tag     solo en main: rc que se promociona (misma imagen, sin rebuild)
#   environment dev | pre | pro | ''
#
# Reglas:
#   develop    -> X.Y.Z-prerelease.N   X.Y.Z = proxima release (minor+1 del ultimo stable, o base de version.json)
#   release/*  -> X.Y.Z-rc.N           idem proxima release
#   hotfix/*   -> X.Y.(Z+1)-rc.N       sobre el ultimo stable
#   main       -> X.Y.Z                la del rc mergeado (retag, sin rebuild)
#   N es incremental por (version, tipo): max(N existente)+1
set -euo pipefail

BRANCH="${1:?uso: semver.sh <branch> [version.json]}"
VERSION_FILE="${2:-version.json}"
SEMVER_RE='^[0-9]+\.[0-9]+\.[0-9]+$'

out() { if [[ -n "${GITHUB_OUTPUT:-}" ]]; then echo "$1=$2" >> "$GITHUB_OUTPUT"; fi; echo "$1=$2"; }

base=$(jq -r '.version' "$VERSION_FILE")
[[ "$base" =~ $SEMVER_RE ]] || { echo "::error::version.json: '$base' no es X.Y.Z"; exit 1; }

# ultimo tag estable vX.Y.Z (vacio si no hay)
latest=$(git tag -l 'v*' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sed 's/^v//' | sort -V | tail -1 || true)

# proxima version de release: version.json manda si es mayor que el ultimo stable
next_release() {
  if [[ -z "$latest" ]]; then echo "$base"; return; fi
  local top; top=$(printf '%s\n%s\n' "$base" "$latest" | sort -V | tail -1)
  if [[ "$top" == "$base" && "$base" != "$latest" ]]; then echo "$base"; return; fi
  IFS=. read -r M m _ <<< "$latest"
  echo "$M.$((m + 1)).0"
}

next_hotfix() {
  [[ -n "$latest" ]] || { echo "::error::hotfix requiere al menos un tag vX.Y.Z estable en main"; exit 1; }
  IFS=. read -r M m p <<< "$latest"
  echo "$M.$m.$((p + 1))"
}

# siguiente N para v<version>-<suffix>.N
next_n() {
  local version=$1 suffix=$2 max
  max=$(git tag -l "v${version}-${suffix}.*" | sed -E "s/^v${version//./\\.}-${suffix}\.//" | grep -E '^[0-9]+$' | sort -n | tail -1 || true)
  echo $(( ${max:-0} + 1 ))
}

kind=""; version=""; tag=""; rc_tag=""; env=""

case "$BRANCH" in
  develop)
    kind=prerelease; env=dev
    version=$(next_release); tag="v${version}-prerelease.$(next_n "$version" prerelease)" ;;
  release/*)
    kind=rc; env=pre
    version=$(next_release); tag="v${version}-rc.$(next_n "$version" rc)" ;;
  hotfix/*)
    kind=rc; env=pre
    version=$(next_hotfix); tag="v${version}-rc.$(next_n "$version" rc)" ;;
  main)
    kind=release; env=pro
    # 1) rc alcanzable desde el 2do padre del merge (rama release/hotfix mergeada)
    rc_tag=$(git describe --tags --abbrev=0 --match 'v*-rc.*' HEAD^2 2>/dev/null || true)
    # 2) fallback (squash / fast-forward): mayor rc cuya version aun no tiene tag estable
    if [[ -z "$rc_tag" ]]; then
      for v in $(git tag -l 'v*-rc.*' | sed -E 's/^v([0-9]+\.[0-9]+\.[0-9]+)-rc\..*/\1/' | sort -Vu); do
        git rev-parse -q --verify "refs/tags/v$v" >/dev/null || cand=$v
      done
      [[ -n "${cand:-}" ]] || { echo "::error::main sin ningun rc pendiente de promocionar"; exit 1; }
      rc_tag="v${cand}-rc.$(( $(next_n "$cand" rc) - 1 ))"
    fi
    version=$(echo "$rc_tag" | sed -E 's/^v([0-9]+\.[0-9]+\.[0-9]+)-rc\..*/\1/')
    tag="v${version}" ;;
  *)
    kind=feature ;;   # feature/* y cualquier otra: solo tests + sonar, sin tag
esac

out kind "$kind"; out version "$version"; out tag "$tag"; out rc_tag "$rc_tag"; out environment "$env"
