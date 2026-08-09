#!/usr/bin/env bash
set -euo pipefail

function semver_lt() { test "$(printf '%s\n' "$@" | sort -r -V | head -n 1)" != "$1"; }

DNS_SERVICE_ACCOUNT=${DNS_SERVICE_ACCOUNT:-kube-dns}
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

TILLER_REGISTRY=${TILLER_REGISTRY:-ghcr.io}
TILLER_IMAGE_NAMESPACE=${TILLER_IMAGE_NAMESPACE:-pasturestack}
DNS_IMAGE_REGISTRY=${DNS_IMAGE_REGISTRY:-ghcr.io}
DNS_IMAGE_NAMESPACE=${DNS_IMAGE_NAMESPACE:-pasturestack}
DNS_REPLICAS=${DNS_REPLICAS:-1}
DNS_CLUSTER_IP=${DNS_CLUSTER_IP:-10.43.0.10}
ADDONS_LOG_VERBOSITY_LEVEL=${ADDONS_LOG_VERBOSITY_LEVEL:-2}
DNS_ROLLOUT_TIMEOUT=${DNS_ROLLOUT_TIMEOUT:-180s}

# Addons Images
# If any of these versions are updated, please also update them in
# addon-templates/README.md

ADDONS_DIR=${ADDONS_DIR:-/etc/kubernetes/addons}

CLUSTER_DNS_IMAGE=${CLUSTER_DNS_IMAGE:-cluster-dns:1.26.9}
TILLER_IMAGE=${TILLER_IMAGE:-tiller:v2.17.1}

while IFS= read -r -d '' f; do
  sed -i "s|\$DNS_IMAGE_REGISTRY|$DNS_IMAGE_REGISTRY|g" "$f"
  sed -i "s|\$DNS_IMAGE_NAMESPACE|$DNS_IMAGE_NAMESPACE|g" "$f"
  sed -i "s|\$DNS_REPLICAS|$DNS_REPLICAS|g" "$f"
  sed -i "s|\$DNS_CLUSTER_IP|$DNS_CLUSTER_IP|g" "$f"
  sed -i "s|\$ADDONS_LOG_VERBOSITY_LEVEL|$ADDONS_LOG_VERBOSITY_LEVEL|g" "$f"
  sed -i "s|\$CLUSTER_DNS_IMAGE|$CLUSTER_DNS_IMAGE|g" "$f"
  sed -i "s|\$TILLER_REGISTRY|$TILLER_REGISTRY|g" "$f"
  sed -i "s|\$TILLER_IMAGE_NAMESPACE|$TILLER_IMAGE_NAMESPACE|g" "$f"
  sed -i "s|\$TILLER_IMAGE|$TILLER_IMAGE|g" "$f"
  sed -i "s|\$TILLER_SERVICE_ACCOUNT|$TILLER_SERVICE_ACCOUNT|g" "$f"
  sed -i "s|\$DNS_SERVICE_ACCOUNT|$DNS_SERVICE_ACCOUNT|g" "$f"
  sed -i "s|\$DNS_APP_LABEL_KEY|$DNS_APP_LABEL_KEY|g" "$f"
done < <(find "$ADDONS_DIR" -name '*.yaml' -print0)

function report_preserved_legacy_addons() {
  local selector resources

  for selector in \
    'k8s-app=kubernetes-dashboard' \
    'k8s-app=heapster' \
    'k8s-app=grafana' \
    'k8s-app=influxdb'; do
    resources=$(kubectl --namespace=kube-system get deployments,replicationcontrollers,services \
      -l "$selector" -o name 2>/dev/null || true)
    if [ -n "$resources" ]; then
      echo "Preserving legacy add-on resources for ${selector}; review and retire them manually after data and dependency validation"
    fi
  done

  if kubectl get clusterrolebinding addons-binding >/dev/null 2>&1; then
    echo 'Legacy addons-binding still exists; review its subjects and remove any obsolete cluster-admin grant manually' >&2
  fi
}

function restore_dns_resources() {
  local deployment_existed="$1"
  local old_generation="$2"
  local service_existed="$3"
  local service_snapshot="$4"
  local service_account_existed="$5"
  local config_map_existed="$6"
  local current_generation

  if [ "$deployment_existed" = true ]; then
    current_generation=$(kubectl --namespace=kube-system get deployment kube-dns \
      -o jsonpath='{.metadata.generation}' 2>/dev/null || true)
    if [ -n "$current_generation" ] && [ "$current_generation" != "$old_generation" ]; then
      kubectl --namespace=kube-system rollout undo deployment/kube-dns || true
      kubectl --namespace=kube-system rollout status deployment/kube-dns \
        --timeout="$DNS_ROLLOUT_TIMEOUT" || true
    fi
  else
    kubectl --namespace=kube-system delete deployment kube-dns --ignore-not-found=true || true
  fi

  if [ "$service_existed" = true ]; then
    kubectl apply -f "$service_snapshot" || true
  else
    kubectl --namespace=kube-system delete service kube-dns --ignore-not-found=true || true
  fi
  [ "$config_map_existed" = true ] || \
    kubectl --namespace=kube-system delete configmap kube-dns --ignore-not-found=true || true
  [ "$service_account_existed" = true ] || \
    kubectl --namespace=kube-system delete serviceaccount "$DNS_SERVICE_ACCOUNT" \
      --ignore-not-found=true || true
}

function verify_dns_bootstrap_rbac() {
  local subjects

  if [ "$DNS_SERVICE_ACCOUNT" != kube-dns ]; then
    echo 'Kubernetes 1.12 bootstrap RBAC supports only the kube-system/kube-dns service account' >&2
    return 1
  fi
  if ! kubectl get clusterrole system:kube-dns >/dev/null 2>&1; then
    echo 'Required Kubernetes bootstrap ClusterRole system:kube-dns is missing' >&2
    return 1
  fi
  subjects=$(kubectl get clusterrolebinding system:kube-dns \
    -o jsonpath='{range .subjects[*]}{.kind}:{.namespace}:{.name}{"\n"}{end}' 2>/dev/null || true)
  if ! grep -Fxq 'ServiceAccount:kube-system:kube-dns' <<< "$subjects"; then
    echo 'Required Kubernetes bootstrap binding for kube-system/kube-dns is missing' >&2
    return 1
  fi
}

function converge_dns() {
  local desired_kubedns_image="${DNS_IMAGE_REGISTRY}/${DNS_IMAGE_NAMESPACE}/${CLUSTER_DNS_IMAGE}"
  local desired_version="${CLUSTER_DNS_IMAGE##*:}"
  local current_image current_version current_cluster_ip old_generation actual_images rollback_dir
  local service_snapshot
  local deployment_existed=false service_existed=false
  local service_account_existed=false config_map_existed=false

  current_cluster_ip=$(kubectl --namespace=kube-system get service kube-dns \
    -o jsonpath='{.spec.clusterIP}' 2>/dev/null || true)
  if [ -n "$current_cluster_ip" ] && [ "$current_cluster_ip" != "$DNS_CLUSTER_IP" ]; then
    echo "Refusing to change kube-dns Service cluster IP from ${current_cluster_ip} to ${DNS_CLUSTER_IP}" >&2
    return 1
  fi

  current_image=$(kubectl --namespace=kube-system get deployment kube-dns \
    -o jsonpath='{.spec.template.spec.containers[?(@.name=="kubedns")].image}' 2>/dev/null || true)
  current_version=${current_image##*:}
  if [ -n "$current_image" ] && [ "$current_image" != "$desired_kubedns_image" ]; then
    if [[ ! "$current_version" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      echo "Refusing to replace kube-dns image with an unrecognized version: ${current_image}" >&2
      return 1
    fi
    if semver_lt "$desired_version" "$current_version"; then
      echo "Keeping newer kube-dns image ${current_image}; desired image is ${desired_kubedns_image}"
      return 0
    fi
  fi

  rollback_dir=$(mktemp -d /tmp/pasturestack-dns-rollback.XXXXXX)
  service_snapshot="${rollback_dir}/kube-dns-service.json"
  if kubectl --namespace=kube-system get service kube-dns >/dev/null 2>&1; then
    service_existed=true
    if ! kubectl --namespace=kube-system get service kube-dns -o json | jq '
      del(
        .metadata.annotations."kubectl.kubernetes.io/last-applied-configuration",
        .metadata.creationTimestamp,
        .metadata.resourceVersion,
        .metadata.selfLink,
        .metadata.uid,
        .status
      )
    ' > "$service_snapshot"; then
      echo 'Unable to snapshot the kube-dns Service before the update' >&2
      rm -rf "$rollback_dir"
      return 1
    fi
  fi
  kubectl --namespace=kube-system get serviceaccount "$DNS_SERVICE_ACCOUNT" \
    >/dev/null 2>&1 && service_account_existed=true
  kubectl --namespace=kube-system get configmap kube-dns \
    >/dev/null 2>&1 && config_map_existed=true

  if kubectl --namespace=kube-system get deployment kube-dns >/dev/null 2>&1; then
    deployment_existed=true
    old_generation=$(kubectl --namespace=kube-system get deployment kube-dns \
      -o jsonpath='{.metadata.generation}')
  else
    old_generation=0
  fi

  if ! kubectl apply -f "${ADDONS_DIR}/dns/kubedns-rbac.yaml" ||
     ! verify_dns_bootstrap_rbac ||
     ! kubectl apply -f "${ADDONS_DIR}/dns/kubedns-svc.yaml" ||
     ! kubectl apply -f "${ADDONS_DIR}/dns/kubedns-controller.yaml"; then
    echo 'Unable to apply the maintained kube-dns resources' >&2
    restore_dns_resources "$deployment_existed" "$old_generation" \
      "$service_existed" "$service_snapshot" "$service_account_existed" \
      "$config_map_existed"
    rm -rf "$rollback_dir"
    return 1
  fi

  if ! kubectl --namespace=kube-system rollout status deployment/kube-dns \
    --timeout="$DNS_ROLLOUT_TIMEOUT"; then
    echo 'kube-dns rollout failed; restoring the previous Deployment revision' >&2
    restore_dns_resources "$deployment_existed" "$old_generation" \
      "$service_existed" "$service_snapshot" "$service_account_existed" \
      "$config_map_existed"
    rm -rf "$rollback_dir"
    return 1
  fi

  actual_images=$(kubectl --namespace=kube-system get deployment kube-dns \
    -o jsonpath='{range .spec.template.spec.containers[*]}{.name}={.image}{"\n"}{end}')
  if [ "$actual_images" != "kubedns=${desired_kubedns_image}" ]; then
    echo "kube-dns rollout produced an unexpected container set: ${actual_images}" >&2
    restore_dns_resources "$deployment_existed" "$old_generation" \
      "$service_existed" "$service_snapshot" "$service_account_existed" \
      "$config_map_existed"
    rm -rf "$rollback_dir"
    return 1
  fi

  echo "kube-dns is ready at ${desired_version}; Service cluster IP ${DNS_CLUSTER_IP} was preserved"
  rm -rf "$rollback_dir"
}

report_preserved_legacy_addons
if [ "${DISABLE_DNS:-false}" != true ]; then
  converge_dns
fi

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

if [ "${DISABLE_TILLER:-false}" != true ]; then
  converge_tiller
fi

nc -k -l 10240 > /dev/null 2>&1
