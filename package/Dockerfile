FROM ubuntu:26.04

ARG TARGETARCH=amd64
ARG IMAGE_VERSION=dev
ARG SOURCE_REVISION=unknown
ARG UBUNTU_MIRROR=http://archive.ubuntu.com/ubuntu
ARG AZURE_CLI_SUITE=noble
ARG DOCKER_VERSION=29.6.2
ARG DOCKER_LINUX_AMD64_SHA256=d6204aea92238e2453d5445c885b9d2e5eb8f82915568ec50edf9dbe12a3ac74
ARG CNI_VERSION=v0.3.0-rancher3
ARG CNI_SHA256=2bfc5df1633b149b4735c6b8dd9d9f3cbc03832d15d8f5302f8307cbb37ca03e

LABEL org.opencontainers.image.source="https://github.com/PastureStack/kubernetes-package" \
      org.opencontainers.image.title="pasturestack-kubernetes-package" \
      org.opencontainers.image.description="PastureStack Kubernetes compatibility package proof-of-concept image" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.opencontainers.image.revision="${SOURCE_REVISION}" \
      org.opencontainers.image.licenses="Apache-2.0" \
      io.pasturestack.migration="true"

ENV DEBIAN_FRONTEND=noninteractive \
    CNI=${CNI_VERSION} \
    PASTURESTACK_LOCALE=en-US

RUN set -eux; \
    find /etc/apt -type f \( -name '*.list' -o -name '*.sources' \) -exec sed -i \
        -e "s|http://security.ubuntu.com/ubuntu|${UBUNTU_MIRROR}|g" \
        -e "s|http://archive.ubuntu.com/ubuntu|${UBUNTU_MIRROR}|g" {} +; \
    printf 'Acquire::Retries "5";\nAcquire::http::Timeout "30";\nAcquire::https::Timeout "30";\nAcquire::http::Pipeline-Depth "0";\n' > /etc/apt/apt.conf.d/80pasturestack-retries; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl gnupg; \
    mkdir -p /etc/apt/keyrings; \
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg; \
    chmod go+r /etc/apt/keyrings/microsoft.gpg; \
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ ${AZURE_CLI_SUITE} main" > /etc/apt/sources.list.d/azure-cli.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        azure-cli \
        cifs-utils \
        conntrack \
        ceph-common \
        curl \
        ethtool \
        file \
        git \
        glusterfs-client \
        ipset \
        iptables \
        jq \
        netcat-openbsd \
        nfs-common \
        open-iscsi \
        socat \
        unzip \
        util-linux \
        wget \
        xfsprogs; \
    /opt/az/bin/python3 -m pip install --no-cache-dir --upgrade \
        cryptography==48.0.1 \
        pyOpenSSL==26.2.0; \
    /opt/az/bin/python3 -c 'import cryptography, OpenSSL; assert cryptography.__version__ == "48.0.1"; assert OpenSSL.__version__ == "26.2.0"'; \
    /opt/az/bin/python3 -m pip check; \
    az version; \
    apt-get autoremove -y; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/bin/pebble

RUN set -eux; \
    case "${TARGETARCH}" in \
        amd64) docker_arch=x86_64; docker_sha="${DOCKER_LINUX_AMD64_SHA256}" ;; \
        *) echo "unsupported TARGETARCH=${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 10 --max-time 300 \
        -o /tmp/docker.tgz "https://download.docker.com/linux/static/stable/${docker_arch}/docker-${DOCKER_VERSION}.tgz"; \
    echo "${docker_sha}  /tmp/docker.tgz" | sha256sum -c -; \
    tar xzf /tmp/docker.tgz -C /tmp docker/docker; \
    install -m 0755 /tmp/docker/docker /usr/bin/docker; \
    mkdir -p /mnt/sda1; \
    ln -sfn /var /mnt/sda1/var; \
    docker --version; \
    rm -rf /tmp/*

# This immutable external tag is retained as a compatibility input. Its vendor
# suffix is source provenance, not PastureStack branding; see COMPATIBILITY.md.
RUN set -eux; \
    mkdir -p /opt/loopback/bin; \
    curl -fsSL --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 10 --max-time 300 \
        -o /tmp/cni.tgz "https://github.com/rancher/cni/releases/download/${CNI_VERSION}/cni-${CNI_VERSION}.tar.gz"; \
    echo "${CNI_SHA256}  /tmp/cni.tgz" | sha256sum -c -; \
    tar xzf /tmp/cni.tgz -C /tmp ./loopback; \
    mv /tmp/loopback /opt/loopback/bin/loopback; \
    rm -rf /tmp/*

COPY update-platform-ca runc-1.10 utils.sh entry.sh addons-update.sh kubectl kubelet kube-proxy kube-apiserver kube-controller-manager kube-scheduler /usr/bin/
COPY kubernetes/cluster/addons /etc/kubernetes/addons/
COPY LICENSE SECURITY.md ORIGIN.md COMPATIBILITY.md /licenses/

ENTRYPOINT ["/usr/bin/entry.sh"]
