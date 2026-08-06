#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
temporary_directory=$(mktemp -d)
cleanup() {
    rm -rf -- "${temporary_directory}"
}
trap cleanup EXIT

test_repo="${temporary_directory}/repository"
mkdir -p "${test_repo}/scripts"
cp "${repo_root}/scripts/release" "${test_repo}/scripts/release"
cat > "${test_repo}/scripts/ci" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n%s\n' "${SOURCE_REVISION}" "${VERSION_OVERRIDE}" > result
EOF
chmod +x "${test_repo}/scripts/ci"

git -C "${test_repo}" init -q
git -C "${test_repo}" config user.name "PastureStack Test"
git -C "${test_repo}" config user.email "test@invalid"
printf 'release gate fixture\n' > "${test_repo}/fixture"
git -C "${test_repo}" add fixture scripts
git -C "${test_repo}" commit -q -m "Create release gate fixture"
head_commit=$(git -C "${test_repo}" rev-parse HEAD)

expect_failure() {
    if (cd "${test_repo}" && "$@") >/dev/null 2>&1; then
        echo "command unexpectedly succeeded: $*" >&2
        exit 1
    fi
}

expect_failure bash scripts/release

printf 'dirty\n' > "${test_repo}/untracked"
expect_failure bash scripts/release
rm "${test_repo}/untracked"

git -C "${test_repo}" tag v1.2.3-pasturestack.1
expect_failure bash scripts/release
git -C "${test_repo}" tag -d v1.2.3-pasturestack.1 >/dev/null

git -C "${test_repo}" tag -a v1.2.3-pasturestack.1 -m "Release fixture"
(cd "${test_repo}" && bash scripts/release)
mapfile -t result < "${test_repo}/result"
test "${result[0]}" = "${head_commit}"
test "${result[1]}" = "v1.2.3-pasturestack.1"
rm "${test_repo}/result"

git -C "${test_repo}" tag -a v1.2.3-pasturestack.2 -m "Ambiguous release fixture"
expect_failure bash scripts/release

echo "KUBERNETES_PACKAGE_RELEASE_GATE_NEGATIVE_TEST_OK revision=${head_commit}"
