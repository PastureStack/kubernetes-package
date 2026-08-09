#!/bin/bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/pasturestack-addon-upgrade.XXXXXX")

cleanup() {
    rm -rf "${fixture_root}"
}
trap cleanup EXIT

mkdir -p "${fixture_root}/bin" "${fixture_root}/addons/dns"
for source in "${repo_root}"/addon-templates/kubectl/dns/*.yaml.sed; do
    target="${fixture_root}/addons/dns/$(basename "${source%.sed}")"
    cp "${source}" "${target}"
done
cp "${repo_root}/addon-templates/kubectl/dns/kubedns-rbac.yaml" \
    "${fixture_root}/addons/dns/kubedns-rbac.yaml"

cat > "${fixture_root}/bin/kubectl" <<'EOF'
#!/bin/bash
set -euo pipefail

printf '%s\n' "$*" >> "${KUBECTL_FIXTURE_LOG}"

if [[ "$*" == *"get ns kube-system"* ]]; then
    exit 0
fi

if [[ "$*" == *"get deployments,replicationcontrollers,services"* ]]; then
    if [[ "$*" == *"k8s-app=kubernetes-dashboard"* ]]; then
        printf '%s\n' 'deployment.extensions/kubernetes-dashboard'
    fi
    exit 0
fi

if [[ "$*" == *"get clusterrolebinding addons-binding"* ]]; then
    exit 0
fi

if [[ "$*" == *"get clusterrole system:kube-dns"* ]]; then
    exit 0
fi

if [[ "$*" == *"get clusterrolebinding system:kube-dns"*"subjects"* ]]; then
    printf '%s\n' 'ServiceAccount:kube-system:kube-dns'
    exit 0
fi

if [[ "$*" == *"get service kube-dns"*"spec.clusterIP"* ]]; then
    printf '%s' "${KUBECTL_FIXTURE_CLUSTER_IP:-10.43.0.10}"
    exit 0
fi

if [[ "$*" == *"get service kube-dns -o json"* ]]; then
    cat <<JSON
{"apiVersion":"v1","kind":"Service","metadata":{"name":"kube-dns","namespace":"kube-system","resourceVersion":"7","uid":"fixture"},"spec":{"clusterIP":"${KUBECTL_FIXTURE_CLUSTER_IP:-10.43.0.10}","ports":[{"name":"dns","port":53,"protocol":"UDP"},{"name":"dns-tcp","port":53,"protocol":"TCP"}],"selector":{"k8s-app":"kube-dns"}}}
JSON
    exit 0
fi

if [[ "$*" == *"get service kube-dns"* ]] ||
   [[ "$*" == *"get serviceaccount kube-dns"* ]] ||
   [[ "$*" == *"get configmap kube-dns"* ]]; then
    exit 0
fi

if [[ "$*" == *"get deployment kube-dns"*"containers"*"kubedns"*"image"* ]]; then
    printf '%s' "ghcr.io/pasturestack/cluster-dns:${KUBECTL_FIXTURE_DNS_VERSION:-1.14.13}"
    exit 0
fi

if [[ "$*" == *"get deployment kube-dns"*"metadata.generation"* ]]; then
    if [ -f "${KUBECTL_FIXTURE_APPLIED}" ]; then
        printf '%s' '8'
    else
        printf '%s' '7'
    fi
    exit 0
fi

if [[ "$*" == *"get deployment kube-dns"*"range .spec.template.spec.containers"* ]]; then
    if [ "${KUBECTL_FIXTURE_UNEXPECTED_IMAGES:-false}" = true ]; then
        printf '%s\n' 'kubedns=ghcr.io/pasturestack/cluster-dns:1.26.9' \
            'sidecar=unexpected.invalid/sidecar:1.0.0'
    else
        cat <<'IMAGES'
kubedns=ghcr.io/pasturestack/cluster-dns:1.26.9
IMAGES
    fi
    exit 0
fi

if [[ "$*" == *"get deployment kube-dns"* ]]; then
    exit 0
fi

if [[ "$*" == *"apply -f "*"/dns/kubedns-"*".yaml"* ]]; then
    : > "${KUBECTL_FIXTURE_APPLIED}"
    exit 0
fi

if [[ "$*" == *"rollout undo deployment/kube-dns"* ]]; then
    : > "${KUBECTL_FIXTURE_UNDONE}"
    exit 0
fi

if [[ "$*" == *"rollout status deployment/kube-dns"* ]] &&
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
export ADDONS_DIR="${fixture_root}/addons"
export DISABLE_TILLER=true

if ! bash "${repo_root}/package/addons-update.sh" > "${fixture_root}/output.log" 2>&1; then
    cat "${fixture_root}/output.log" >&2
    exit 1
fi

grep -Fq "apply -f ${fixture_root}/addons/dns/kubedns-rbac.yaml" "${KUBECTL_FIXTURE_LOG}"
grep -Fq "apply -f ${fixture_root}/addons/dns/kubedns-svc.yaml" "${KUBECTL_FIXTURE_LOG}"
grep -Fq "apply -f ${fixture_root}/addons/dns/kubedns-controller.yaml" "${KUBECTL_FIXTURE_LOG}"
grep -Fq 'rollout status deployment/kube-dns --timeout=180s' "${KUBECTL_FIXTURE_LOG}"
grep -Fq 'Preserving legacy add-on resources for k8s-app=kubernetes-dashboard' \
    "${fixture_root}/output.log"
grep -Fq 'Legacy addons-binding still exists' "${fixture_root}/output.log"
grep -Fq 'kube-dns is ready at 1.26.9; Service cluster IP 10.43.0.10 was preserved' \
    "${fixture_root}/output.log"
grep -Fq 'image: ghcr.io/pasturestack/cluster-dns:1.26.9' \
    "${fixture_root}/addons/dns/kubedns-controller.yaml"
grep -Fq 'serviceAccountName: kube-dns' \
    "${fixture_root}/addons/dns/kubedns-controller.yaml"
grep -Fq 'runAsNonRoot: true' "${fixture_root}/addons/dns/kubedns-controller.yaml"
grep -Fq 'runAsUser: 65532' "${fixture_root}/addons/dns/kubedns-controller.yaml"
grep -Fq 'initialDelaySeconds: 75' "${fixture_root}/addons/dns/kubedns-controller.yaml"
grep -Fq -- '--initial-sync-timeout=60s' "${fixture_root}/addons/dns/kubedns-controller.yaml"
grep -Fq 'name: KUBE_FEATURE_WatchListClient' "${fixture_root}/addons/dns/kubedns-controller.yaml"
grep -A1 -F 'name: KUBE_FEATURE_WatchListClient' \
    "${fixture_root}/addons/dns/kubedns-controller.yaml" | grep -Fq 'value: "false"'
grep -Fq 'preferredDuringSchedulingIgnoredDuringExecution:' \
    "${fixture_root}/addons/dns/kubedns-controller.yaml"
if grep -Fq 'requiredDuringSchedulingIgnoredDuringExecution:' \
    "${fixture_root}/addons/dns/kubedns-controller.yaml"; then
    echo 'KUBERNETES_PACKAGE_DNS_SINGLE_HOST_ROLLOUT_BLOCKED' >&2
    exit 1
fi
grep -Fq 'targetPort: dns-local' "${fixture_root}/addons/dns/kubedns-svc.yaml"
grep -Fq 'targetPort: dns-tcp-local' "${fixture_root}/addons/dns/kubedns-svc.yaml"
if grep -Eq 'dnsmasq|name: sidecar|k8s-dns-sidecar' \
    "${fixture_root}/addons/dns/kubedns-controller.yaml"; then
    echo 'KUBERNETES_PACKAGE_LEGACY_DNS_SIDECAR_PRESENT' >&2
    exit 1
fi
if grep -E 'replace --force|delete .*kubernetes-dashboard|delete .*heapster|delete .*grafana|delete .*influxdb' \
    "${KUBECTL_FIXTURE_LOG}"; then
    echo 'KUBERNETES_PACKAGE_LEGACY_ADDON_MUTATION_PRESENT' >&2
    exit 1
fi

: > "${fixture_root}/newer.log"
rm -f "${KUBECTL_FIXTURE_APPLIED}" "${KUBECTL_FIXTURE_UNDONE}"
export KUBECTL_FIXTURE_LOG="${fixture_root}/newer.log"
export KUBECTL_FIXTURE_DNS_VERSION=1.27.0
if ! bash "${repo_root}/package/addons-update.sh" > "${fixture_root}/newer-output.log" 2>&1; then
    cat "${fixture_root}/newer-output.log" >&2
    exit 1
fi
grep -Fq 'Keeping newer kube-dns image ghcr.io/pasturestack/cluster-dns:1.27.0' \
    "${fixture_root}/newer-output.log"
if grep -Fq "apply -f ${fixture_root}/addons/dns/kubedns-rbac.yaml" "${fixture_root}/newer.log"; then
    echo 'KUBERNETES_PACKAGE_DNS_DOWNGRADE_ATTEMPTED' >&2
    exit 1
fi

: > "${fixture_root}/mismatch.log"
rm -f "${KUBECTL_FIXTURE_APPLIED}" "${KUBECTL_FIXTURE_UNDONE}"
export KUBECTL_FIXTURE_LOG="${fixture_root}/mismatch.log"
export KUBECTL_FIXTURE_DNS_VERSION=1.14.13
export KUBECTL_FIXTURE_CLUSTER_IP=10.96.0.10
if bash "${repo_root}/package/addons-update.sh" > "${fixture_root}/mismatch-output.log" 2>&1; then
    echo 'KUBERNETES_PACKAGE_DNS_CLUSTER_IP_MISMATCH_ACCEPTED' >&2
    exit 1
fi
grep -Fq 'Refusing to change kube-dns Service cluster IP from 10.96.0.10 to 10.43.0.10' \
    "${fixture_root}/mismatch-output.log"

: > "${fixture_root}/failure.log"
rm -f "${KUBECTL_FIXTURE_APPLIED}" "${KUBECTL_FIXTURE_UNDONE}"
export KUBECTL_FIXTURE_LOG="${fixture_root}/failure.log"
export KUBECTL_FIXTURE_CLUSTER_IP=10.43.0.10
export KUBECTL_FIXTURE_FAIL_ROLLOUT=true
if bash "${repo_root}/package/addons-update.sh" > "${fixture_root}/failure-output.log" 2>&1; then
    echo 'KUBERNETES_PACKAGE_DNS_EXPECTED_ROLLOUT_FAILURE' >&2
    exit 1
fi
grep -Fq 'rollout undo deployment/kube-dns' "${fixture_root}/failure.log"
grep -Eq 'apply -f /tmp/pasturestack-dns-rollback\.[^/]*/kube-dns-service.json' \
    "${fixture_root}/failure.log"
grep -Fq 'kube-dns rollout failed; restoring the previous Deployment revision' \
    "${fixture_root}/failure-output.log"

: > "${fixture_root}/unexpected.log"
rm -f "${KUBECTL_FIXTURE_APPLIED}" "${KUBECTL_FIXTURE_UNDONE}"
export KUBECTL_FIXTURE_LOG="${fixture_root}/unexpected.log"
export KUBECTL_FIXTURE_FAIL_ROLLOUT=false
export KUBECTL_FIXTURE_UNEXPECTED_IMAGES=true
if bash "${repo_root}/package/addons-update.sh" > "${fixture_root}/unexpected-output.log" 2>&1; then
    echo 'KUBERNETES_PACKAGE_DNS_UNEXPECTED_CONTAINER_SET_ACCEPTED' >&2
    exit 1
fi
grep -Fq 'rollout undo deployment/kube-dns' "${fixture_root}/unexpected.log"
grep -Eq 'apply -f /tmp/pasturestack-dns-rollback\.[^/]*/kube-dns-service.json' \
    "${fixture_root}/unexpected.log"
grep -Fq 'kube-dns rollout produced an unexpected container set:' \
    "${fixture_root}/unexpected-output.log"

echo 'KUBERNETES_PACKAGE_ADDON_UPGRADE_FIXTURE_OK dns=1.26.9 legacy=preserved rbac=bootstrap-least-privilege service-rollback=verified container-set=exact'
