#!/usr/bin/env bash
# "Validado en PRE" = el commit tiene un deployment OK en el environment `pre` (API de GitHub).
# Sustituye a los tags rc de git: el repo solo tiene tags vX.Y.Z.
#
# Uso: validated.sh <sha>                          -> imprime true|false
#      validated.sh --latest <develop_ref> <main_ref> -> imprime el sha validado mas reciente que esta en
#                                                     develop y aun NO en main (candidato a release); falla si no hay
# Requiere: gh (GH_TOKEN, GITHUB_REPOSITORY) y git con historial completo.
set -euo pipefail
REPO="${GITHUB_REPOSITORY:?}"
ENV_NAME="${PRE_ENV:-pre}"

deployments() { gh api "repos/$REPO/deployments?environment=$ENV_NAME&per_page=100" --jq '.[] | "\(.id) \(.sha)"'; }
# un deployment antiguo pasa a "inactive" al desplegar otro: vale con que ALGUN estado sea success
ok() { [[ "$(gh api "repos/$REPO/deployments/$1/statuses" --jq 'any(.[]; .state=="success")')" == "true" ]]; }

case "${1:?uso: validated.sh <sha> | --latest <develop_ref> <main_ref>}" in
  --latest)
    DEV="${2:?}"; MAIN="${3:?}"
    while read -r id sha; do
      [[ -n "$id" ]] || continue
      git cat-file -e "$sha^{commit}" 2>/dev/null || continue
      git merge-base --is-ancestor "$sha" "$DEV" || continue
      ! git merge-base --is-ancestor "$sha" "$MAIN" || continue
      if ok "$id"; then echo "$sha"; exit 0; fi
    done < <(deployments)
    echo "::error::develop no tiene ningun commit validado en PRE pendiente de release" >&2
    exit 1 ;;
  *)
    SHA="$1"
    while read -r id sha; do
      [[ "$sha" == "$SHA" ]] || continue
      if ok "$id"; then echo true; exit 0; fi
    done < <(deployments)
    echo false ;;
esac
