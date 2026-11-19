#!/usr/bin/env bash
# Calcula la version semver automatica segun la rama (ver docs/gitflow-v3.png).
#
# Uso: semver.sh <branch> [version.json]
#      semver.sh --last-rc [version.json]   -> ultimo commit de develop con tag rc (validado en PRE)
# Requiere: git con tags y ramas descargados (fetch-depth: 0), jq.
# Salida (key=value; a $GITHUB_OUTPUT si existe y siempre a stdout):
#   kind         feature | prerelease | rc | promote | noop
#   version      X.Y.Z
#   tag          tag git del build: vX.Y.Z-prerelease.N (develop) | vX.Y.Z-rc.N (rc) ; vacio si no construye
#   rc_tag       tag rc: el que se crea en PRE (develop/rc) o el que ya tiene HEAD (promote)
#   n            N compartido prerelease/rc
#   image_tag    tag de la imagen del build (= tag sin la "v")
#   environment  dev | pre | ''
#
# kind:
#   feature     feature/*, PRs: solo tests + sonar
#   prerelease  develop: build X.Y.Z-prerelease.N -> DEV -> clone a PRE como X.Y.Z-rc.N
#   rc          release/* o hotfix/* con commits nuevos (fix): build X.Y.Z-rc.N -> PRE
#   promote     release/* o hotfix/* cuyo HEAD ya tiene tag rc: NO construye, solo promociona a PRO
#   noop        main, o hotfix recien creado sin commits propios
#
# Version:
#   develop     proxima release por Conventional Commits desde el ultimo vX.Y.Z estable
#               (BREAKING -> major, feat -> minor, resto -> patch). version.json es el suelo.
#   release/*   X.Y.Z = nombre de la rama (release/X.Y.Z); si no es semver se calcula.
#   hotfix/*    X.Y.Z = nombre de la rama (hotfix/X.Y.Z); si no es semver, patch+1 del ultimo estable.
#   N es UNICO y compartido: max(N de tags prerelease y rc de esa version)+1.
# El tag estable vX.Y.Z lo crea el job "finalize" tras el deploy OK en PRO.
set -euo pipefail

BRANCH="${1:?uso: semver.sh <branch|--last-rc> [version.json]}"
VERSION_FILE="${2:-version.json}"
SEMVER_RE='^[0-9]+\.[0-9]+\.[0-9]+$'

out() { if [[ -n "${GITHUB_OUTPUT:-}" ]]; then echo "$1=$2" >> "$GITHUB_OUTPUT"; fi; echo "$1=$2"; }

base=$(jq -r '.version' "$VERSION_FILE")
[[ "$base" =~ $SEMVER_RE ]] || { echo "::error::version.json: '$base' no es X.Y.Z"; exit 1; }

latest=$(git tag -l 'v*' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sed 's/^v//' | sort -V | tail -1 || true)

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
  printf '%s\n%s\n' "$base" "$calc" | sort -V | tail -1
}

next_hotfix() {
  [[ -n "$latest" ]] || { echo "::error::hotfix requiere al menos un tag vX.Y.Z estable en main"; exit 1; }
  bump "$latest" patch
}

# N compartido: max N entre tags prerelease.* y rc.* de esa version, +1
next_n() {
  local version=$1 max
  max=$(git tag -l "v${version}-prerelease.*" "v${version}-rc.*" \
        | sed -E 's/.*\.([0-9]+)$/\1/' | grep -E '^[0-9]+$' | sort -n | tail -1 || true)
  echo $(( ${max:-0} + 1 ))
}

version_from_branch() { local v="${BRANCH#*/}"; [[ "$v" =~ $SEMVER_RE ]] && echo "$v" || true; }

rc_at_head() { # rc tag (mayor) que apunta a HEAD para esa version; vacio si no hay
  git tag --points-at HEAD --list "v${1}-rc.*" | sort -V | tail -1
}

last_rc() { # ultimo rc en develop cuya version aun no tiene tag estable
  local t v best=""
  while read -r t; do
    [[ -n "$t" ]] || continue
    v=$(sed -E 's/^v([0-9]+\.[0-9]+\.[0-9]+)-rc\..*/\1/' <<< "$t")
    git rev-parse -q --verify "refs/tags/v$v" >/dev/null && continue
    best=$t
  done < <(git tag --merged "${DEVELOP_REF:-origin/develop}" -l 'v*-rc.*' | sort -V)
  echo "$best"
}

kind=""; version=""; tag=""; rc_tag=""; n=""; env=""

case "$BRANCH" in
  --last-rc)
    rc_tag=$(last_rc)
    [[ -n "$rc_tag" ]] || { echo "::error::develop no tiene ningun rc validado en PRE pendiente de release"; exit 1; }
    version=$(sed -E 's/^v([0-9]+\.[0-9]+\.[0-9]+)-rc\..*/\1/' <<< "$rc_tag")
    out version "$version"; out rc_tag "$rc_tag"; out rc_sha "$(git rev-list -n1 "$rc_tag")"
    exit 0 ;;
  develop)
    kind=prerelease; env=dev
    version=$(next_release); n=$(next_n "$version")
    tag="v${version}-prerelease.${n}"; rc_tag="v${version}-rc.${n}" ;;
  release/*|hotfix/*)
    env=pre
    if [[ "$BRANCH" == release/* ]]; then
      version=$(version_from_branch); [[ -n "$version" ]] || version=$(next_release)
    else
      version=$(version_from_branch); [[ -n "$version" ]] || version=$(next_hotfix)
    fi
    if [[ "$BRANCH" == hotfix/* ]] && git rev-parse -q --verify origin/main >/dev/null && git merge-base --is-ancestor HEAD origin/main; then
      kind=noop; env=""
    else
      rc_tag=$(rc_at_head "$version")
      if [[ -n "$rc_tag" ]]; then
        kind=promote                       # ya validado en PRE: no se construye
      else
        kind=rc; n=$(next_n "$version"); tag="v${version}-rc.${n}"; rc_tag="$tag"
      fi
    fi ;;
  main) kind=noop ;;
  *)    kind=feature ;;
esac

out kind "$kind"; out version "$version"; out tag "$tag"; out rc_tag "$rc_tag"; out n "$n"
out image_tag "${tag#v}"; out environment "$env"
