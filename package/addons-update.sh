#!/usr/bin/env bash
set -euo pipefail

function semver_lt() { test "$(printf '%s\n' "$@" | sort -r -V | head -n 1)" != "$1"; }

SYSTEM_SERVICE_ACCOUNT=${SYSTEM_SERVICE_ACCOUNT:-pasturestack-system}
DNS_APP_LABEL_KEY=${DNS_APP_LABEL_KEY:-pasturestack-app}
TILLER_SERVICE_ACCOUNT=${TILLER_SERVICE_ACCOUNT:-pasturestack-tiller}

if [ "${DISABLE_ADDONS:-false}" = "true" ]; then
    echo "addons have been disabled"
    sleep infinity
fi

export KUBECONFIG=/etc/kubernetes/ssl/kubeconfig

while ! kubectl --namespace=kube-system get ns kube-system >/dev/null 2>&1; do
#  echo "Waiting for kubernetes API to come up..."
  sleep 2
done

# Remove old influx
kubectl delete --namespace kube-system deployment influxdb-grafana 2>/dev/null || true

cat <<EOF | kubectl apply -f - || true
apiVersion: v1
kind: ServiceAccount
metadata:
  name: "${SYSTEM_SERVICE_ACCOUNT}"
  namespace: "kube-system"

---

apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: addons-binding
subjects:
- kind: ServiceAccount
  name: "${SYSTEM_SERVICE_ACCOUNT}"
  namespace: kube-system
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
EOF

cat <<EOF | kubectl apply -f - || true
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-dns
  namespace: kube-system
  labels:
    addonmanager.kubernetes.io/mode: EnsureExists
EOF

DOCKER_IO_REGISTRY=${REGISTRY:-docker.io}
TILLER_REGISTRY=${TILLER_REGISTRY:-ghcr.io}
TILLER_IMAGE_NAMESPACE=${TILLER_IMAGE_NAMESPACE:-pasturestack}
INFLUXDB_RETENTION=${INFLUXDB_RETENTION:-0s}
DNS_REPLICAS=${DNS_REPLICAS:-1}
DNS_CLUSTER_IP=${DNS_CLUSTER_IP:-10.43.0.10}
BASE_IMAGE_NAMESPACE=${BASE_IMAGE_NAMESPACE:-pasturestack}
ADDONS_LOG_VERBOSITY_LEVEL=${ADDONS_LOG_VERBOSITY_LEVEL:-2}
DASHBOARD_CPU_LIMIT=${DASHBOARD_CPU_LIMIT:-100m}
DASHBOARD_MEMORY_LIMIT=${DASHBOARD_MEMORY_LIMIT:-300Mi}

INFLUXDB_HOST_PATH=${INFLUXDB_HOST_PATH:-}
if [ "$INFLUXDB_HOST_PATH" == "" ]; then
  INFLUXDB_VOLUME="emptyDir: {}"
else
  INFLUXDB_VOLUME="hostPath:\n          path: $INFLUXDB_HOST_PATH"
fi

# Addons Images
# If any of these versions are updated, please also update them in
# addon-templates/README.md

ADDONS_DIR=${ADDONS_DIR:-/etc/kubernetes/addons}

DASHBOARD_IMAGE=kubernetes-dashboard-amd64:v1.8.3
KUBEDNS_IMAGE=k8s-dns-kube-dns-amd64:1.14.13
DNSMASQ_IMAGE=k8s-dns-dnsmasq-nanny-amd64:1.14.13
DNS_SIDECAR_IMAGE=k8s-dns-sidecar-amd64:1.14.13
GRAFANA_IMAGE=heapster-grafana-amd64:v4.4.3
HEAPSTER_IMAGE=heapster-amd64:v1.5.4
INFLUXDB_IMAGE=heapster-influxdb-amd64:v1.3.3
TILLER_IMAGE=${TILLER_IMAGE:-tiller:v2.17.0-pasturestack.2}

for f in $(find $ADDONS_DIR -name '*.yaml'); do
  sed -i "s|\$DOCKER_IO_REGISTRY|$DOCKER_IO_REGISTRY|g" ${f}
  sed -i "s|\$INFLUXDB_VOLUME|$INFLUXDB_VOLUME|g" ${f}
  sed -i "s|\$INFLUXDB_RETENTION|$INFLUXDB_RETENTION|g" ${f}
  sed -i "s|\$DNS_REPLICAS|$DNS_REPLICAS|g" ${f}
  sed -i "s|\$BASE_IMAGE_NAMESPACE|$BASE_IMAGE_NAMESPACE|g" ${f}
  sed -i "s|\$DNS_CLUSTER_IP|$DNS_CLUSTER_IP|g" ${f}
  sed -i "s|\$ADDONS_LOG_VERBOSITY_LEVEL|$ADDONS_LOG_VERBOSITY_LEVEL|g" ${f}
  sed -i "s|\$DASHBOARD_IMAGE|$DASHBOARD_IMAGE|g" ${f}
  sed -i "s|\$KUBEDNS_IMAGE|$KUBEDNS_IMAGE|g" ${f}
  sed -i "s|\$DNSMASQ_IMAGE|$DNSMASQ_IMAGE|g" ${f}
  sed -i "s|\$DNS_SIDECAR_IMAGE|$DNS_SIDECAR_IMAGE|g" ${f}
  sed -i "s|\$GRAFANA_IMAGE|$GRAFANA_IMAGE|g" ${f}
  sed -i "s|\$HEAPSTER_IMAGE|$HEAPSTER_IMAGE|g" ${f}
  sed -i "s|\$INFLUXDB_IMAGE|$INFLUXDB_IMAGE|g" ${f}
  sed -i "s|\$TILLER_REGISTRY|$TILLER_REGISTRY|g" ${f}
  sed -i "s|\$TILLER_IMAGE_NAMESPACE|$TILLER_IMAGE_NAMESPACE|g" ${f}
  sed -i "s|\$TILLER_IMAGE|$TILLER_IMAGE|g" ${f}
  sed -i "s|\$TILLER_SERVICE_ACCOUNT|$TILLER_SERVICE_ACCOUNT|g" ${f}
  sed -i "s|\$SYSTEM_SERVICE_ACCOUNT|$SYSTEM_SERVICE_ACCOUNT|g" ${f}
  sed -i "s|\$DNS_APP_LABEL_KEY|$DNS_APP_LABEL_KEY|g" ${f}
  sed -i "s|\$DASHBOARD_CPU_LIMIT|$DASHBOARD_CPU_LIMIT|g" ${f}
  sed -i "s|\$DASHBOARD_MEMORY_LIMIT|$DASHBOARD_MEMORY_LIMIT|g" ${f}
done

addons_images=(
    "k8s-app=kubernetes-dashboard,$DASHBOARD_IMAGE,$ADDONS_DIR/dashboard"
    "k8s-app=kube-dns,$KUBEDNS_IMAGE,$ADDONS_DIR/dns"
    "k8s-app=grafana,$GRAFANA_IMAGE,$ADDONS_DIR/heapster/grafana"
    "k8s-app=heapster,$HEAPSTER_IMAGE,$ADDONS_DIR/heapster/heapster"
    "k8s-app=influxdb,$INFLUXDB_IMAGE,$ADDONS_DIR/heapster/influxdb"
   )

# Check Addon version
for i in "${addons_images[@]}"; do
  current_version=$(kubectl get deployments -n kube-system -o=jsonpath="{..image}" -l "$(echo $i | cut -d"," -f1)" | cut -d" " -f1 | cut -d":" -f2 || true)
  desired_version=$(grep -r "$(echo $i | cut -d"," -f2)" $ADDONS_DIR | cut -d":" -f4 || true)
  if [ -z "${current_version}" ]; then
    kubectl --namespace=kube-system replace --force -f $(echo $i | cut -d"," -f3)
  elif [ "${current_version}" == "${desired_version}" ]; then
    kubectl --namespace=kube-system replace --force -f $(echo $i | cut -d"," -f3)
  elif semver_lt ${current_version} ${desired_version}; then
    kubectl --namespace=kube-system replace --force -f $(echo $i | cut -d"," -f3)
  fi
done

# Helm 2 release records are cluster data. Update Tiller in place and compare
# canonical record content before and after; never use replace --force for this
# path. The operator-facing durable backup is scripts/tiller-release-backup.
function snapshot_tiller_release_records() {
  kubectl get configmaps,secrets --all-namespaces -l OWNER=TILLER \
    -o json | jq -cS '.items[] | {
      apiVersion,
      kind,
      metadata: {
        name: .metadata.name,
        namespace: .metadata.namespace,
        labels: (.metadata.labels // {}),
        annotations: (.metadata.annotations // {})
      },
      type: (.type // null),
      immutable: (.immutable // null),
      data: (.data // {}),
      binaryData: (.binaryData // {})
    }' | sort
}

function restore_tiller_resources() {
  local deployment_existed="$1"
  local old_generation="$2"
  local service_existed="$3"
  local service_account_existed="$4"
  local role_existed="$5"
  local binding_existed="$6"
  local current_generation

  if [ "${deployment_existed}" = true ]; then
    current_generation=$(kubectl --namespace=kube-system get deployment tiller-deploy \
      -o jsonpath='{.metadata.generation}' 2>/dev/null || true)
    if [ -n "${current_generation}" ] && [ "${current_generation}" != "${old_generation}" ]; then
      kubectl --namespace=kube-system rollout undo deployment/tiller-deploy || true
      kubectl --namespace=kube-system rollout status deployment/tiller-deploy --timeout=120s || true
    fi
  else
    kubectl --namespace=kube-system delete deployment tiller-deploy --ignore-not-found=true || true
  fi

  [ "${service_existed}" = true ] || kubectl --namespace=kube-system delete service tiller-deploy --ignore-not-found=true || true
  [ "${binding_existed}" = true ] || kubectl delete clusterrolebinding pasturestack-tiller-compat --ignore-not-found=true || true
  [ "${role_existed}" = true ] || kubectl delete clusterrole pasturestack-tiller-compat --ignore-not-found=true || true
  [ "${service_account_existed}" = true ] || kubectl --namespace=kube-system delete serviceaccount "${TILLER_SERVICE_ACCOUNT}" --ignore-not-found=true || true
}

function converge_tiller() {
  local desired_image="${TILLER_REGISTRY}/${TILLER_IMAGE_NAMESPACE}/${TILLER_IMAGE}"
  local desired_version="${TILLER_IMAGE##*:}"
  local current_image current_version old_generation new_generation
  local release_snapshot_dir release_count_before release_count_after missing_count extra_count
  local deployment_existed=false service_existed=false service_account_existed=false role_existed=false binding_existed=false

  current_image=$(kubectl --namespace=kube-system get deployment tiller-deploy \
    -o jsonpath='{.spec.template.spec.containers[?(@.name=="tiller")].image}' 2>/dev/null || true)
  current_version=${current_image##*:}

  if [ -n "${current_image}" ] && [ "${current_image}" != "${desired_image}" ]; then
    if [[ ! "${current_version}" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
      echo "Refusing to replace Tiller image with an unrecognized version: ${current_image}" >&2
      return 1
    fi
    if ! semver_lt "${current_version}" "${desired_version}"; then
      echo "Keeping newer Tiller image ${current_image}; desired image is ${desired_image}"
      return 0
    fi
  fi

  umask 077
  release_snapshot_dir=$(mktemp -d /tmp/pasturestack-tiller-release-records.XXXXXX)
  if ! snapshot_tiller_release_records > "${release_snapshot_dir}/before"; then
    echo "Unable to snapshot Helm 2 release records before the Tiller update" >&2
    rm -rf "${release_snapshot_dir}"
    return 1
  fi
  release_count_before=$(wc -l < "${release_snapshot_dir}/before" | tr -d ' ')

  if kubectl --namespace=kube-system get deployment tiller-deploy >/dev/null 2>&1; then
    deployment_existed=true
    old_generation=$(kubectl --namespace=kube-system get deployment tiller-deploy \
      -o jsonpath='{.metadata.generation}')
  else
    old_generation=0
  fi
  kubectl --namespace=kube-system get service tiller-deploy >/dev/null 2>&1 && service_existed=true
  kubectl --namespace=kube-system get serviceaccount "${TILLER_SERVICE_ACCOUNT}" >/dev/null 2>&1 && service_account_existed=true
  kubectl get clusterrole pasturestack-tiller-compat >/dev/null 2>&1 && role_existed=true
  kubectl get clusterrolebinding pasturestack-tiller-compat >/dev/null 2>&1 && binding_existed=true

  if ! kubectl apply -f "${ADDONS_DIR}/helm"; then
    echo "Unable to apply the maintained Tiller resources" >&2
    restore_tiller_resources "${deployment_existed}" "${old_generation}" "${service_existed}" \
      "${service_account_existed}" "${role_existed}" "${binding_existed}"
    rm -rf "${release_snapshot_dir}"
    return 1
  fi

  new_generation=$(kubectl --namespace=kube-system get deployment tiller-deploy \
    -o jsonpath='{.metadata.generation}')
  if ! kubectl --namespace=kube-system rollout status deployment/tiller-deploy --timeout=120s; then
    echo "Tiller rollout failed; restoring the previous Deployment revision" >&2
    restore_tiller_resources "${deployment_existed}" "${old_generation}" "${service_existed}" \
      "${service_account_existed}" "${role_existed}" "${binding_existed}"
    rm -rf "${release_snapshot_dir}"
    return 1
  fi

  if ! snapshot_tiller_release_records > "${release_snapshot_dir}/after"; then
    echo "Unable to verify Helm 2 release records after the Tiller update; restoring the previous Deployment revision" >&2
    restore_tiller_resources "${deployment_existed}" "${old_generation}" "${service_existed}" \
      "${service_account_existed}" "${role_existed}" "${binding_existed}"
    rm -rf "${release_snapshot_dir}"
    return 1
  fi
  release_count_after=$(wc -l < "${release_snapshot_dir}/after" | tr -d ' ')
  missing_count=$(comm -23 "${release_snapshot_dir}/before" "${release_snapshot_dir}/after" | wc -l | tr -d ' ')
  extra_count=$(comm -13 "${release_snapshot_dir}/before" "${release_snapshot_dir}/after" | wc -l | tr -d ' ')

  if [ "${missing_count}" -ne 0 ] || [ "${extra_count}" -ne 0 ]; then
    echo "Tiller update verification found changed-or-missing=${missing_count} changed-or-added=${extra_count} Helm 2 release record(s); restoring the previous Deployment revision" >&2
    restore_tiller_resources "${deployment_existed}" "${old_generation}" "${service_existed}" \
      "${service_account_existed}" "${role_existed}" "${binding_existed}"
    rm -rf "${release_snapshot_dir}"
    return 1
  fi

  echo "Tiller is ready at ${desired_image}; Helm 2 release records before=${release_count_before} after=${release_count_after} changed-or-missing=0 changed-or-added=0"
  rm -rf "${release_snapshot_dir}"
}

converge_tiller

# Remove orphaned heapster
kubectl -n kube-system delete -l 'k8s-app=heapster' -l 'version=v6' replicaset 2>/dev/null || true

nc -k -l 10240 > /dev/null 2>&1
