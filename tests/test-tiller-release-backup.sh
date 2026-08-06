#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd -P)
fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/pasturestack-tiller-backup-test.XXXXXX")

cleanup() {
    rm -rf -- "${fixture_root}"
}
trap cleanup EXIT

mkdir -p "${fixture_root}/bin" "${fixture_root}/output"

cat > "${fixture_root}/bin/kubectl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$*" == *"get configmaps,secrets"* ]]; then
    secret_value='c3VwZXItc2VjcmV0LXJlbGVhc2UtZGF0YQ=='
    if [ "${KUBECTL_FIXTURE_STATE:-same}" = changed ]; then
        secret_value='Y2hhbmdlZC1yZWxlYXNlLWRhdGE='
    fi
    emit_release_list() {
        cat <<JSON
{
  "apiVersion": "v1",
  "kind": "List",
  "items": [
    {
      "apiVersion": "v1",
      "kind": "ConfigMap",
      "metadata": {
        "name": "release-one.v1",
        "namespace": "team-a",
        "labels": {"OWNER": "TILLER", "STATUS": "DEPLOYED", "VERSION": "1"},
        "annotations": {"example.invalid/owner": "fixture"}
      },
      "data": {"release": "Y29uZmlnLXJlbGVhc2UtZGF0YQ=="}
    },
    {
      "apiVersion": "v1",
      "kind": "Secret",
      "metadata": {
        "name": "release-two.v2",
        "namespace": "team-b",
        "labels": {"OWNER": "TILLER", "STATUS": "DEPLOYED", "VERSION": "2"}
      },
      "type": "helm.sh/release.v1",
      "data": {"release": "${secret_value}"}
    }
  ]
}
JSON
    }
    if [ "${KUBECTL_FIXTURE_STATE:-same}" = added ]; then
        emit_release_list | jq '.items += [{
          apiVersion: "v1",
          kind: "Secret",
          metadata: {
            name: "release-three.v1",
            namespace: "team-c",
            labels: {OWNER: "TILLER", STATUS: "DEPLOYED", VERSION: "1"}
          },
          type: "helm.sh/release.v1",
          data: {release: "YWRkZWQ="}
        }]'
    elif [ "${KUBECTL_FIXTURE_STATE:-same}" = missing ]; then
        emit_release_list | jq '.items = [.items[0]]'
    else
        emit_release_list
    fi
    exit 0
fi

if [[ "$*" == *"get deployment tiller-deploy -o json"* ]]; then
    cat <<'JSON'
{
  "apiVersion": "apps/v1",
  "kind": "Deployment",
  "metadata": {"name": "tiller-deploy", "namespace": "kube-system"},
  "spec": {"template": {"spec": {"containers": [
    {"name": "tiller", "image": "ghcr.io/pasturestack/tiller:v2.17.0-pasturestack.2"}
  ]}}}
}
JSON
    exit 0
fi

if [[ "$*" == "version -o json" ]]; then
    printf '%s\n' '{"serverVersion":{"gitVersion":"v1.12.10-pasturestack.3"}}'
    exit 0
fi

if [[ "$*" == "config current-context" ]]; then
    printf '%s\n' 'fixture-context'
    exit 0
fi

echo "unexpected kubectl invocation: $*" >&2
exit 1
EOF
chmod +x "${fixture_root}/bin/kubectl"

export PATH="${fixture_root}/bin:${PATH}"
backup_tool="${repo_root}/scripts/tiller-release-backup"
bundle="${fixture_root}/output/release-backup"

"${backup_tool}" snapshot --output "${bundle}" > "${fixture_root}/snapshot.log"
grep -Fq 'TILLER_RELEASE_BACKUP_SNAPSHOT_OK records=2 configmaps=1 secrets=1' \
    "${fixture_root}/snapshot.log"
if grep -Fq 'super-secret-release-data' "${fixture_root}/snapshot.log"; then
    echo 'TILLER_RELEASE_BACKUP_TEST_SECRET_LEAKED_TO_OUTPUT' >&2
    exit 1
fi
[ "$(stat -c '%a' "${bundle}")" = 700 ]
while IFS= read -r file; do
    [ "$(stat -c '%a' "${file}")" = 600 ] || {
        echo "TILLER_RELEASE_BACKUP_TEST_BAD_FILE_MODE file=${file}" >&2
        exit 1
    }
done < <(find "${bundle}" -maxdepth 1 -type f -print)

"${backup_tool}" verify --input "${bundle}" > "${fixture_root}/verify.log"
grep -Fq 'TILLER_RELEASE_BACKUP_VERIFY_OK records=2' "${fixture_root}/verify.log"

"${backup_tool}" compare --input "${bundle}" > "${fixture_root}/compare-same.log"
grep -Fq 'TILLER_RELEASE_BACKUP_COMPARE_OK missing=0 added=0 changed=0' \
    "${fixture_root}/compare-same.log"

for state in changed added missing; do
    export KUBECTL_FIXTURE_STATE=${state}
    if "${backup_tool}" compare --input "${bundle}" \
        > "${fixture_root}/compare-${state}.log" 2>&1; then
        echo "TILLER_RELEASE_BACKUP_TEST_EXPECTED_DIFFERENCE state=${state}" >&2
        exit 1
    else
        status=$?
    fi
    [ "${status}" -eq 3 ] || {
        echo "TILLER_RELEASE_BACKUP_TEST_BAD_DIFFERENCE_STATUS state=${state} status=${status}" >&2
        exit 1
    }
done
grep -Fq 'CHANGED Secret/team-b/release-two.v2' "${fixture_root}/compare-changed.log"
grep -Fq 'ADDED Secret/team-c/release-three.v1' "${fixture_root}/compare-added.log"
grep -Fq 'MISSING Secret/team-b/release-two.v2' "${fixture_root}/compare-missing.log"
unset KUBECTL_FIXTURE_STATE

cp -a "${bundle}" "${fixture_root}/output/corrupt-backup"
printf '\n' >> "${fixture_root}/output/corrupt-backup/release-records.json"
if "${backup_tool}" verify --input "${fixture_root}/output/corrupt-backup" \
    > "${fixture_root}/corrupt.log" 2>&1; then
    echo 'TILLER_RELEASE_BACKUP_TEST_EXPECTED_CHECKSUM_FAILURE' >&2
    exit 1
fi
grep -Fq 'bundle checksum verification failed' "${fixture_root}/corrupt.log"

if "${backup_tool}" snapshot --output "${repo_root}/forbidden-release-backup" \
    > "${fixture_root}/source-tree.log" 2>&1; then
    echo 'TILLER_RELEASE_BACKUP_TEST_EXPECTED_SOURCE_TREE_REFUSAL' >&2
    exit 1
fi
grep -Fq 'output directory must be outside the source tree' "${fixture_root}/source-tree.log"
[ ! -e "${repo_root}/forbidden-release-backup" ]

if "${backup_tool}" snapshot --output "${bundle}" \
    > "${fixture_root}/existing-output.log" 2>&1; then
    echo 'TILLER_RELEASE_BACKUP_TEST_EXPECTED_EXISTING_OUTPUT_REFUSAL' >&2
    exit 1
fi
grep -Fq 'output already exists' "${fixture_root}/existing-output.log"

echo 'KUBERNETES_PACKAGE_TILLER_RELEASE_BACKUP_TEST_OK records=2 drift=verified permissions=verified'
