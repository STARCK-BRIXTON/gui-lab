#!/usr/bin/env bash
# Calcula la version semver automatica segun la rama (ver docs/gitflow-v4.png).
#
# Uso: semver.sh <branch> [version.json]
# Requiere: git con tags y ramas descargados (fetch-depth: 0), jq.
# Entorno opcional:
#   BUILD_N        numero de build (en Actions: github.run_number). Sin el: commits desde el ultimo vX.Y.Z.
#   PRE_VALIDATED  "true" si el HEAD ya se desplego OK en PRE (lo decide validated.sh con la API de deployments).
# Salida (key=value; a $GITHUB_OUTPUT si existe y siempre a stdout):
#   kind         feature | prerelease | rc | promote | noop
#   version      X.Y.Z
#   n            numero de build
#   image_tag    tag de la imagen que construye este run: X.Y.Z-prerelease.N (develop) | X.Y.Z-rc.N (rc); vacio si no construye
#   rc_image     tag de la imagen en PRE: X.Y.Z-rc.N (develop: clone de la de DEV; rc: la propia)
#   sha_tag      sha-<sha7>: tag inmutable de la imagen del commit (lo que se promueve a PRO)
#   environment  dev | pre | ''
#
# IMPORTANTE: prerelease y rc son tags de IMAGEN (ACR), nunca tags de git. El unico tag git es vX.Y.Z,
# que crea el job "finalize" tras el deploy OK en PRO.
#
# kind:
#   feature     feature/*, PRs: solo tests + sonar
#   prerelease  develop: build X.Y.Z-prerelease.N -> DEV -> clone a PRE como X.Y.Z-rc.N
#   rc          release/* o hotfix/* con commit sin validar en PRE (fix): build X.Y.Z-rc.N -> PRE
#   promote     release/* o hotfix/* con PRE_VALIDATED=true: NO construye, solo promociona a PRO
#   noop        main, o hotfix recien creado sin commits propios
#
# Version:
#   develop     proxima release por Conventional Commits desde el ultimo vX.Y.Z estable
#               (BREAKING -> major, feat -> minor, resto -> patch). version.json es el suelo.
#   release/*   X.Y.Z = nombre de la rama (release/X.Y.Z); si no es semver se calcula.
#   hotfix/*    X.Y.Z = nombre de la rama (hotfix/X.Y.Z); si no es semver, patch+1 del ultimo estable.
set -euo pipefail

BRANCH="${1:?uso: semver.sh <branch> [version.json]}"
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

# N del build: github.run_number en Actions (unico; un re-run conserva el mismo N);
# sin el, commits desde el ultimo tag estable (reproducible en local)
build_n() {
  if [[ -n "${BUILD_N:-}" ]]; then echo "$BUILD_N"; return; fi
  if [[ -n "$latest" ]]; then git rev-list --count "v${latest}..HEAD"; else git rev-list --count HEAD; fi
}

version_from_branch() { local v="${BRANCH#*/}"; [[ "$v" =~ $SEMVER_RE ]] && echo "$v" || true; }

kind=""; version=""; image_tag=""; rc_image=""; n=""; env=""
sha_tag="sha-$(git rev-parse --short=7 HEAD)"

case "$BRANCH" in
  develop)
    kind=prerelease; env=dev
    version=$(next_release); n=$(build_n)
    image_tag="${version}-prerelease.${n}"; rc_image="${version}-rc.${n}" ;;
  release/*|hotfix/*)
    env=pre
    if [[ "$BRANCH" == release/* ]]; then
      version=$(version_from_branch); [[ -n "$version" ]] || version=$(next_release)
    else
      version=$(version_from_branch); [[ -n "$version" ]] || version=$(next_hotfix)
    fi
    if [[ "$BRANCH" == hotfix/* ]] && git rev-parse -q --verify origin/main >/dev/null && git merge-base --is-ancestor HEAD origin/main; then
      kind=noop; env=""
    elif [[ "${PRE_VALIDATED:-false}" == "true" ]]; then
      kind=promote                         # ya validado en PRE: no se construye
    else
      kind=rc; n=$(build_n); image_tag="${version}-rc.${n}"; rc_image="$image_tag"
    fi ;;
  main) kind=noop ;;
  *)    kind=feature ;;
esac

out kind "$kind"; out version "$version"; out n "$n"; out image_tag "$image_tag"
out rc_image "$rc_image"; out sha_tag "$sha_tag"; out environment "$env"
