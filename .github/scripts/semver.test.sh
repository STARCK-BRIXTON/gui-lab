#!/usr/bin/env bash
# Pruebas de semver.sh y validated.sh en un repo git temporal. Uso: bash .github/scripts/semver.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; S="$HERE/semver.sh"; V="$HERE/validated.sh"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
echo '{"version":"1.0.0"}' > "$T/version.json"
cd "$T"; git init -q -b main; git config user.email t@t; git config user.name t
pass=0; fail=0
get() { "$S" "$1" "$T/version.json" 2>/dev/null | grep "^$2=" | head -1 | cut -d= -f2-; }
check() { # check "desc" branch key expected
  local got; got=$(get "$2" "$3")
  if [[ "$got" == "$4" ]]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $1 -> $3 esperado '$4' obtenido '$got'"; fi
}
eq() { if [[ "$2" == "$3" ]]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $1 esperado '$3' obtenido '$2'"; fi; }
c() { git commit -q --allow-empty -m "$1"; }
sync_origin() { git update-ref refs/remotes/origin/main main; git update-ref refs/remotes/origin/develop develop; }

c "init"; git checkout -q -b develop; sync_origin
c "feat: a"
check "primera release usa version.json" develop version 1.0.0
check "N fallback = commits desde el inicio" develop n 2
export BUILD_N=7
check "imagen prerelease" develop image_tag 1.0.0-prerelease.7
check "imagen rc en PRE comparte N" develop rc_image 1.0.0-rc.7
check "sha_tag" develop sha_tag "sha-$(git rev-parse --short=7 HEAD)"
check "develop -> DEV" develop environment dev
export BUILD_N=8
check "run nuevo -> N nuevo" develop image_tag 1.0.0-prerelease.8
c "fix: b"; c "feat: c"; sync_origin
check "no se crean tags de git: el bump sigue por commits" develop version 1.0.0
eq "el repo no tiene ningun tag" "$(git tag -l | wc -l | tr -d ' ')" 0

# release/1.0.0
git checkout -q -b release/1.0.0
export PRE_VALIDATED=true
check "release validada en PRE -> promote" release/1.0.0 kind promote
check "promote no construye" release/1.0.0 image_tag ""
export PRE_VALIDATED=false
c "fix: en release"
check "release con fix sin validar -> rc" release/1.0.0 kind rc
export BUILD_N=9
check "rc.N con N del run" release/1.0.0 image_tag 1.0.0-rc.9
check "rc se despliega en PRE" release/1.0.0 rc_image 1.0.0-rc.9
export PRE_VALIDATED=true
check "tras validar el fix -> promote" release/1.0.0 kind promote
export PRE_VALIDATED=false

# promocion: merge a main y tag estable (unico tag git)
git checkout -q main; git merge -q --no-ff release/1.0.0 -m "chore(release): v1.0.0"; git tag v1.0.0
git checkout -q develop; git merge -q --no-ff main -m "sync"; sync_origin
c "feat: d"; check "tras release, feat -> minor" develop version 1.1.0
c "refactor!: e"; check "breaking -> major" develop version 2.0.0

# version.json como suelo
echo '{"version":"3.0.0"}' > "$T/version.json"; check "version.json suelo" develop version 3.0.0
echo '{"version":"1.0.0"}' > "$T/version.json"

# hotfix
git checkout -q main; git checkout -q -b hotfix/1.0.1; sync_origin
check "hotfix sin commits -> noop" hotfix/1.0.1 kind noop
c "fix: urgente"
check "hotfix con fix -> rc" hotfix/1.0.1 kind rc
check "hotfix imagen rc" hotfix/1.0.1 image_tag 1.0.1-rc.9
PRE_VALIDATED=true check "hotfix validado -> promote" hotfix/1.0.1 kind promote
check "hotfix nombre no semver -> patch+1" hotfix/new version 1.0.1

# otros
check "feature" feature/x kind feature
check "main noop" main kind noop

# validated.sh con gh simulado: deployments pre (id sha) y sus estados
git checkout -q develop
SHA_OK=$(git rev-parse HEAD~1); SHA_OLD=$(git rev-parse HEAD~2); SHA_REL=$(git rev-parse main)
mkdir -p "$T/bin"
cat > "$T/bin/gh" <<GH
#!/usr/bin/env bash
case "\$2" in
  *deployments?environment=pre*) printf '3 %s\n2 %s\n1 %s\n' "$SHA_REL" "$SHA_OK" "$SHA_OLD" ;;
  */deployments/3/statuses) echo true ;;   # ya esta en main (publicado)
  */deployments/2/statuses) echo true ;;   # validado, en develop, no en main
  */deployments/1/statuses) echo true ;;
  *) echo false ;;
esac
GH
chmod +x "$T/bin/gh"
export PATH="$T/bin:$PATH" GITHUB_REPOSITORY=o/r
eq "validated.sh <sha> true" "$("$V" "$SHA_OK")" true
eq "validated.sh <sha> false" "$("$V" "$(git rev-parse HEAD)")" false
eq "--latest ignora lo ya publicado en main" "$("$V" --latest develop main)" "$SHA_OK"

echo "ok=$pass fail=$fail"; [[ $fail -eq 0 ]]
