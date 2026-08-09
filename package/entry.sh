#!/bin/bash
set -euo pipefail

locale=${PASTURESTACK_LOCALE:-en-US}
case "${locale}" in
    en-US|zh-TW) ;;
    *) echo "unsupported PASTURESTACK_LOCALE=${locale}; use en-US or zh-TW" >&2; exit 2 ;;
esac

operator_message() {
    local key=$1
    case "${locale}:${key}" in
        en-US:waiting-metadata) echo "Waiting for control-platform metadata" ;;
        zh-TW:waiting-metadata) echo "正在等待控制平台中繼資料" ;;
        *) echo "${key}" ;;
    esac
}

metadata_base_url=${PLATFORM_METADATA_URL:-http://metadata/2015-12-19}
platform_api_url=${PLATFORM_URL:-${CATTLE_URL:-}}
platform_access_key=${PLATFORM_ACCESS_KEY:-${CATTLE_ACCESS_KEY:-}}
platform_secret_key=${PLATFORM_SECRET_KEY:-${CATTLE_SECRET_KEY:-}}

docker_info() {
    local api_version="${PASTURESTACK_DOCKER_API_VERSION:-${DOCKER_API_VERSION:-}}"
    if [ -n "$api_version" ]; then
        DOCKER_API_VERSION="$api_version" docker "$@"
    else
        docker "$@"
    fi
}

is_cgroup_v2() {
    [ -f /sys/fs/cgroup/cgroup.controllers ]
}

append_kubelet_arg_if_missing() {
    local key=$1
    local value=$2
    local arg
    for arg in "${kubelet_args[@]}"; do
        case "${arg}" in
            "${key}"|"${key}="*) return ;;
        esac
    done
    kubelet_args+=("${value}")
}

disable_kubelet_feature_gate() {
    local feature=$1
    local replacement="${feature}=false"
    local index
    local value
    local gate
    local gate_index
    local found
    local separate
    local -a gates

    for index in "${!kubelet_args[@]}"; do
        separate=false
        case "${kubelet_args[$index]}" in
            --feature-gates=*)
                value=${kubelet_args[$index]#--feature-gates=}
                ;;
            --feature-gates)
                separate=true
                index=$((index + 1))
                value=${kubelet_args[$index]:-}
                ;;
            *)
                continue
                ;;
        esac

        IFS=',' read -r -a gates <<< "${value}"
        found=false
        for gate_index in "${!gates[@]}"; do
            gate=${gates[$gate_index]}
            if [[ "${gate}" == "${feature}="* ]]; then
                gates[$gate_index]=${replacement}
                found=true
            fi
        done
        if [ "${found}" != true ]; then
            gates+=("${replacement}")
        fi
        value=$(IFS=','; echo "${gates[*]}")
        if [ "${separate}" = true ]; then
            kubelet_args[$index]=${value}
        else
            kubelet_args[$index]="--feature-gates=${value}"
        fi
        return
    done

    kubelet_args+=("--feature-gates=${replacement}")
}

if [ "$1" == "kubelet" ]; then
    if [ -d /var/run/nscd ]; then
        mount --bind $(mktemp -d) /var/run/nscd
    fi
fi

while ! curl -fsS "${metadata_base_url}/stacks/Kubernetes/services/kubernetes/uuid"; do
    operator_message waiting-metadata
    sleep 1
done

/usr/bin/update-platform-ca

# k8s service certificate
UUID=$(curl -fsS "${metadata_base_url}/stacks/Kubernetes/services/kubernetes/uuid")
ACTION=$(curl -fsS -u "${platform_access_key}:${platform_secret_key}" "${platform_api_url}/services?uuid=${UUID}" | jq -r '.data[0].actions.certificate')
KUBERNETES_URL=${KUBERNETES_URL:-https://kubernetes.kubernetes.pasturestack.internal:6443}

if [ -n "$ACTION" ]; then
    mkdir -p /etc/kubernetes/ssl
    cd /etc/kubernetes/ssl
    curl -fsS -u "${platform_access_key}:${platform_secret_key}" -X POST "${ACTION}" > certs.zip
    unzip -o certs.zip
    cd $OLDPWD

    TOKEN=$(cat /etc/kubernetes/ssl/key.pem | sha256sum | awk '{print $1}')

    cat > /etc/kubernetes/ssl/kubeconfig << EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    api-version: v1
    certificate-authority: /etc/kubernetes/ssl/ca.pem
    server: "$KUBERNETES_URL"
  name: "Default"
contexts:
- context:
    cluster: "Default"
    user: "Default"
  name: "Default"
current-context: "Default"
users:
- name: "Default"
  user:
    token: "$TOKEN"
EOF
fi
# etcd service certificate
ETCD_UUID=$(curl -fsS "${metadata_base_url}/stacks/Kubernetes/services/etcd/uuid")
ETCD_ACTION=$(curl -fsS -u "${platform_access_key}:${platform_secret_key}" "${platform_api_url}/services?uuid=${ETCD_UUID}" | jq -r '.data[0].actions.certificate')

if [ -n "$ETCD_ACTION" ]; then
    mkdir -p /etc/kubernetes/etcd
    cd /etc/kubernetes/etcd
    curl -fsS -u "${platform_access_key}:${platform_secret_key}" -X POST "${ETCD_ACTION}" > etcd_certs.zip
    unzip -o etcd_certs.zip
    cd $OLDPWD

fi

cat > /etc/kubernetes/authconfig << EOF
clusters:
- name: pasturestack-kubernetes-authentication-bridge
  cluster:
    server: ${AUTHENTICATION_BRIDGE_URL:-http://kubernetes-authentication-bridge}

users:
- name: pasturestack-kubernetes

current-context: webhook
contexts:
- context:
    cluster: pasturestack-kubernetes-authentication-bridge
    user: pasturestack-kubernetes
  name: webhook
EOF

# Cloud provider config (if cloudprovider is not rancher)
if ! echo ${@} | grep -q "cloud-provider=rancher"; then
    # Only applicable to kubelet/kube-apiserver/kube-controller-manager
    if [ "$1" == "kubelet" ] || [ "$1" == "kube-apiserver" ] || [ "$1" == "kube-controller-manager" ]; then
        # Check if Azure specific cloud provider config needs to be generated
        if echo ${@} | grep -q "cloud-provider=azure"; then
            AZURE_CLOUD_PROVIDER=1
            source utils.sh
            get_azure_config  > /etc/kubernetes/cloud-provider-config
        fi
        # Check if additional cloud provider config needs to be applied
        if [[ -n "`echo -n "$CLOUD_PROVIDER_CONFIG"`" ]]; then
            # If Azure cloud provider is not configured, write cloud provider config
            if [[ -z ${AZURE_CLOUD_PROVIDER+x} ]]; then
                echo -n "$CLOUD_PROVIDER_CONFIG" > /etc/kubernetes/cloud-provider-config
            # If Azure cloud provider is configured, append to file instead of overwrite
            else
                echo -n "$CLOUD_PROVIDER_CONFIG" >> /etc/kubernetes/cloud-provider-config
            fi
        fi
    fi
fi

# Check for configuration errors
if echo ${@} | grep -q "cloud-config=/etc/kubernetes/cloud-provider-config"; then
    if [ ! -f /etc/kubernetes/cloud-provider-config ]; then
        echo "Configuration error, cloud-provider-config parameter configured but no file present"
        echo "Cloud provider config can only be configured when using 'azure' or 'aws' cloudprovider"
        exit 1
    fi
fi

if [ "$1" == "kubelet" ]; then
    for i in $(docker_info 2>&1  | grep -i 'docker root dir' | cut -f2 -d:) /var/lib/docker /run /var/run; do
        for m in $(tac /proc/mounts | awk '{print $2}' | grep ^${i}/); do
            if [ "$m" != "/var/run/nscd" ] && [ "$m" != "/run/nscd" ]; then
                umount $m || true
            fi
        done
    done
    mount --rbind /host/dev /dev
    if ! is_cgroup_v2; then
        mount -o rw,remount /sys/fs/cgroup 2>/dev/null || true
        for i in /sys/fs/cgroup/*; do
            if [ -d "$i" ]; then
                 mkdir -p "$i/kubepods"
            fi
        done
        if [ -d /sys/fs/cgroup/cpu,cpuacct/ ]
        then
            mkdir -p /sys/fs/cgroup/cpuacct,cpu/
            mount --bind /sys/fs/cgroup/cpu,cpuacct/ /sys/fs/cgroup/cpuacct,cpu/
            mkdir -p /sys/fs/cgroup/net_prio,net_cls/
            mount --bind /sys/fs/cgroup/net_cls,net_prio/ /sys/fs/cgroup/net_prio,net_cls/
        fi
    fi
fi

FQDN=$(hostname --fqdn || hostname)

if [ "$1" == "kubelet" ]; then
    CGROUPDRIVER=$(docker_info | grep -i 'cgroup driver' | awk '{print $3}')
    kubelet_args=("$@")
    if is_cgroup_v2; then
        append_kubelet_arg_if_missing --cgroups-per-qos --cgroups-per-qos=false
        append_kubelet_arg_if_missing --enforce-node-allocatable --enforce-node-allocatable=
        append_kubelet_arg_if_missing --experimental-allocatable-ignore-eviction --experimental-allocatable-ignore-eviction=true
        append_kubelet_arg_if_missing --eviction-hard --eviction-hard=
        disable_kubelet_feature_gate LocalStorageCapacityIsolation
    fi
    # Azure API uses hostnames not FQDNs, if FQDN is used,
    # kubelet wouldn't be able to get node information from the cloud provider.
    if [ "${CLOUD_PROVIDER}" == "azure" ]; then
      FQDN=$(hostname -s)
    fi
    exec "${kubelet_args[@]}" --cgroup-driver="$CGROUPDRIVER" --hostname-override "${FQDN}"
fi

if [ "$1" == "kube-proxy" ]; then
    exec "$@" --hostname-override ${FQDN}
fi

if [ "$1" == "kube-apiserver" ]; then
    legacy_agent_service_name=${LEGACY_AGENT_SERVICE_NAME:-rancher-kubernetes-agent}
    agent_service=$(curl -fsS -u "${platform_access_key}:${platform_secret_key}" \
        "${platform_api_url}/services?name=${legacy_agent_service_name}")
    agent_label=$(printf '%s' "${agent_service}" | jq -r '.data[0].launchConfig.labels["io.rancher.k8s.agent"] // empty')
    if [ -z "${agent_label}" ]; then
        agent_service_url=$(printf '%s' "${agent_service}" | jq -r '.data[0].links.self // empty')
        if [ -n "${agent_service_url}" ]; then
            curl -fsS -u "${platform_access_key}:${platform_secret_key}" -X DELETE "${agent_service_url}"
        fi
    fi

    CONTAINERIP=$(curl -fsS "${metadata_base_url}/self/container/ips/0")
    exec "$@" "--advertise-address=$CONTAINERIP"
fi

exec "$@"
