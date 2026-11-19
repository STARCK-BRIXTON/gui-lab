#!/usr/bin/env bash
# Pruebas de semver.sh en un repo git temporal. Uso: bash .github/scripts/semver.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; S="$HERE/semver.sh"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
echo '{"version":"1.0.0"}' > "$T/version.json"
cd "$T"; git init -q -b main; git config user.email t@t; git config user.name t
pass=0; fail=0
get() { "$S" "$1" "$T/version.json" 2>/dev/null | grep "^$2=" | head -1 | cut -d= -f2-; }
check() { # check "desc" branch key expected
  local got; got=$(get "$2" "$3")
  if [[ "$got" == "$4" ]]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $1 -> $3 esperado '$4' obtenido '$got'"; fi
}
c() { git commit -q --allow-empty -m "$1"; }
sync_origin() { git update-ref refs/remotes/origin/main main; git update-ref refs/remotes/origin/develop develop; }

c "init"; git checkout -q -b develop; sync_origin
c "feat: a"
check "primera release usa version.json" develop version 1.0.0
check "N inicial" develop n 1
check "tag prerelease" develop tag v1.0.0-prerelease.1
check "rc_tag comparte N" develop rc_tag v1.0.0-rc.1
git tag v1.0.0-prerelease.1; git tag v1.0.0-rc.1
check "N compartido avanza" develop n 2
c "fix: b"; git tag v1.0.0-prerelease.2; git tag v1.0.0-rc.2
c "feat: c"                                   # develop avanza; PRE puede estar congelado (sin rc)
sync_origin
check "last-rc = ultimo rc validado" --last-rc rc_tag v1.0.0-rc.2

# release/1.0.0 en el commit con rc.2
git checkout -q -b release/1.0.0 v1.0.0-rc.2
check "release en commit rc -> promote" release/1.0.0 kind promote
check "promote usa su rc" release/1.0.0 rc_tag v1.0.0-rc.2
check "promote no construye" release/1.0.0 tag ""
c "fix: en release"
check "release con fix -> rc" release/1.0.0 kind rc
check "rc.N+1 compartido" release/1.0.0 tag v1.0.0-rc.3
git tag v1.0.0-rc.3
check "release con fix ya tagueado -> promote" release/1.0.0 kind promote

# promocion: merge a main y tag estable
git checkout -q main; git merge -q --no-ff release/1.0.0 -m "chore(release): v1.0.0"; git tag v1.0.0
git checkout -q develop; git merge -q --no-ff main -m "sync"; sync_origin
check "feat c quedo fuera de la release -> minor" develop version 1.1.0
c "refactor!: e"; check "breaking -> major" develop version 2.0.0
check "last-rc ignora versiones ya publicadas (falla sin rc pendiente)" --last-rc rc_tag ""

# version.json como suelo
echo '{"version":"3.0.0"}' > "$T/version.json"; check "version.json suelo" develop version 3.0.0
echo '{"version":"1.0.0"}' > "$T/version.json"

# hotfix
git checkout -q main; git checkout -q -b hotfix/1.0.1; sync_origin
check "hotfix sin commits -> noop" hotfix/1.0.1 kind noop
c "fix: urgente"
check "hotfix con fix -> rc" hotfix/1.0.1 kind rc
check "hotfix tag rc.1" hotfix/1.0.1 tag v1.0.1-rc.1
git tag v1.0.1-rc.1
check "hotfix tagueado -> promote" hotfix/1.0.1 kind promote
check "hotfix nombre no semver -> patch+1" hotfix/new version 1.0.1

# otros
check "feature" feature/x kind feature
check "main noop" main kind noop

echo "ok=$pass fail=$fail"; [[ $fail -eq 0 ]]
