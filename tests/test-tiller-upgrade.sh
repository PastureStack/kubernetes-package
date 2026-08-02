#!/bin/bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/pasturestack-tiller-upgrade.XXXXXX")

cleanup() {
    rm -rf "${fixture_root}"
}
trap cleanup EXIT

mkdir -p "${fixture_root}/bin" "${fixture_root}/addons-success" "${fixture_root}/addons-failure"
cp -R "${repo_root}/addon-templates/kubectl/helm" "${fixture_root}/addons-success/helm"
cp -R "${repo_root}/addon-templates/kubectl/helm" "${fixture_root}/addons-failure/helm"

cat > "${fixture_root}/bin/kubectl" <<'EOF'
#!/bin/bash
set -euo pipefail

printf '%s\n' "$*" >> "${KUBECTL_FIXTURE_LOG}"

if [[ "$*" == *"get ns kube-system"* ]]; then
    exit 0
fi

if [[ "$*" == *"get configmaps,secrets"* ]]; then
    printf '%s\n' \
        'ConfigMap team-a release-one' \
        'Secret team-b release-two'
    exit 0
fi

if [[ "$*" == *"get deployment tiller-deploy"*"containers"*"image"* ]]; then
    printf '%s' 'docker.io/pasturestack/tiller:v2.11.0'
    exit 0
fi

if [[ "$*" == *"get deployment tiller-deploy"*"metadata.generation"* ]]; then
    if [ -f "${KUBECTL_FIXTURE_APPLIED}" ]; then
        printf '%s' '8'
    else
        printf '%s' '7'
    fi
    exit 0
fi

if [[ "$*" == *"get deployment tiller-deploy"* ]]; then
    exit 0
fi

if [[ "$*" == *"get serviceaccount"* ]] ||
   [[ "$*" == *"get clusterrole "* ]] ||
   [[ "$*" == *"get clusterrolebinding "* ]]; then
    exit 1
fi

if [[ "$*" == *"apply -f "*"/helm"* ]]; then
    : > "${KUBECTL_FIXTURE_APPLIED}"
    exit 0
fi

if [[ "$*" == *"rollout undo deployment/tiller-deploy"* ]]; then
    : > "${KUBECTL_FIXTURE_UNDONE}"
    exit 0
fi

if [[ "$*" == *"rollout status deployment/tiller-deploy"* ]] &&
   [ "${KUBECTL_FIXTURE_FAIL_ROLLOUT:-false}" = true ] &&
   [ ! -f "${KUBECTL_FIXTURE_UNDONE}" ]; then
    exit 1
fi

exit 0
EOF

cat > "${fixture_root}/bin/nc" <<'EOF'
#!/bin/bash
exit 0
EOF

chmod +x "${fixture_root}/bin/kubectl" "${fixture_root}/bin/nc"

export PATH="${fixture_root}/bin:${PATH}"
export KUBECTL_FIXTURE_LOG="${fixture_root}/kubectl.log"
export KUBECTL_FIXTURE_APPLIED="${fixture_root}/applied"
export KUBECTL_FIXTURE_UNDONE="${fixture_root}/undone"
export ADDONS_DIR="${fixture_root}/addons-success"

bash "${repo_root}/package/addons-update.sh" > "${fixture_root}/output.log" 2>&1

grep -Fq "apply -f ${fixture_root}/addons-success/helm" "${KUBECTL_FIXTURE_LOG}"
grep -Fq 'rollout status deployment/tiller-deploy --timeout=120s' "${KUBECTL_FIXTURE_LOG}"
if grep -E 'replace --force -f .*/helm([[:space:]]|$)' "${KUBECTL_FIXTURE_LOG}"; then
    echo 'TILLER_UPGRADE_FIXTURE_FORCE_REPLACE_PRESENT' >&2
    exit 1
fi

grep -Fq 'image: ghcr.io/pasturestack/tiller:v2.17.0-pasturestack.1' \
    "${fixture_root}/addons-success/helm/tiller-deploy.yaml"
grep -Fq 'serviceAccountName: "pasturestack-tiller"' \
    "${fixture_root}/addons-success/helm/tiller-deploy.yaml"
grep -Fq 'release records before=2 after=2 missing=0' "${fixture_root}/output.log"

: > "${fixture_root}/kubectl-failure.log"
rm -f "${KUBECTL_FIXTURE_APPLIED}" "${KUBECTL_FIXTURE_UNDONE}"
export KUBECTL_FIXTURE_LOG="${fixture_root}/kubectl-failure.log"
export KUBECTL_FIXTURE_FAIL_ROLLOUT=true
export ADDONS_DIR="${fixture_root}/addons-failure"
if bash "${repo_root}/package/addons-update.sh" > "${fixture_root}/failure-output.log" 2>&1; then
    echo 'TILLER_UPGRADE_FIXTURE_EXPECTED_ROLLOUT_FAILURE' >&2
    exit 1
fi
grep -Fq 'rollout undo deployment/tiller-deploy' "${fixture_root}/kubectl-failure.log"
grep -Fq 'Tiller rollout failed; restoring the previous Deployment revision' \
    "${fixture_root}/failure-output.log"

echo 'KUBERNETES_PACKAGE_TILLER_UPGRADE_FIXTURE_OK records=2 missing=0 rollback=verified'
