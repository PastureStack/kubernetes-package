FROM docker:29.6.2-cli@sha256:be132a9f282288de4afaf63379dff75711fda0147c6b72a9df44e51841402144 AS snapshot-ca-certificates

FROM ubuntu:26.04@sha256:678c6550cc43645e08669028bc177f50be4e7c5b8cca677067b1914d4afc7a03

COPY --from=snapshot-ca-certificates /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY ubuntu-apt.lock /licenses/ubuntu-apt.lock

ARG TARGETARCH=amd64
ARG IMAGE_VERSION=dev
ARG SOURCE_REVISION=unknown
ARG AZURE_CLI_VERSION=2.89.0
ARG AZURE_CLI_DEB_VERSION=2.89.0-1~noble
ARG AZURE_CLI_DEB_SHA256=5244e06ecb7c77a97d58bdb782e23445a3b123fb4422bb56810428131bc8f902
ARG CRYPTOGRAPHY_VERSION=48.0.1
ARG CRYPTOGRAPHY_WHEEL_SHA256=0ee6ea481db1ab889cba043ec1eda17bb9c1ea79db6722f779c3667f9f70322f
ARG PYOPENSSL_VERSION=26.2.0
ARG PYOPENSSL_WHEEL_SHA256=4f9d971bc5298b8bc1fab282803da04bf000c755d4ad9d99b52de2569ca19a70
ARG DOCKER_VERSION=29.6.2
ARG DOCKER_LINUX_AMD64_SHA256=d6204aea92238e2453d5445c885b9d2e5eb8f82915568ec50edf9dbe12a3ac74
ARG CNI_VERSION=v1.9.1
ARG CNI_SOURCE_COMMIT=adc3e6b5b581638afbd194cf2e9319ecbb0151a1
ARG CNI_LICENSE_SHA256=b40930bbcf80744c86c46a12bc9da056641d722716c378f5659b9e555ef833e1
ARG CNI_BUILD_GO_VERSION=1.26.5

LABEL org.opencontainers.image.source="https://github.com/PastureStack/kubernetes-package" \
      org.opencontainers.image.title="pasturestack-kubernetes-package" \
      org.opencontainers.image.description="PastureStack Kubernetes compatibility package proof-of-concept image" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.opencontainers.image.revision="${SOURCE_REVISION}" \
      org.opencontainers.image.licenses="Apache-2.0" \
      io.pasturestack.azure-cli.version="${AZURE_CLI_VERSION}" \
      io.pasturestack.cryptography.version="${CRYPTOGRAPHY_VERSION}" \
      io.pasturestack.pyopenssl.version="${PYOPENSSL_VERSION}" \
      io.pasturestack.cni.version="${CNI_VERSION}" \
      io.pasturestack.cni.revision="${CNI_SOURCE_COMMIT}" \
      io.pasturestack.cni.go.version="${CNI_BUILD_GO_VERSION}" \
      io.pasturestack.migration="true"

ENV DEBIAN_FRONTEND=noninteractive \
    CNI=${CNI_VERSION} \
    PASTURESTACK_LOCALE=en-US

# The CA donor, Ubuntu snapshot, exact direct-package versions, Azure CLI .deb,
# and Python wheels are independently locked. No mutable vendor APT repository
# or unconstrained pip resolver participates in this build.
RUN set -eux; \
    . /licenses/ubuntu-apt.lock; \
    find /etc/apt -type f \( -name '*.list' -o -name '*.sources' \) -exec sed -i \
        -e 's|http://security.ubuntu.com/ubuntu|https://security.ubuntu.com/ubuntu|g' \
        -e 's|http://archive.ubuntu.com/ubuntu|https://archive.ubuntu.com/ubuntu|g' {} +; \
    printf 'Acquire::Retries "5";\nAcquire::http::Timeout "30";\nAcquire::https::Timeout "30";\nAcquire::http::Pipeline-Depth "0";\nAcquire::https::CaInfo "/etc/ssl/certs/ca-certificates.crt";\nAcquire::AllowInsecureRepositories "false";\nAPT::Get::AllowUnauthenticated "false";\n' > /etc/apt/apt.conf.d/80pasturestack-retries; \
    apt-get --snapshot "${UBUNTU_APT_SNAPSHOT}" update; \
    apt-get --snapshot "${UBUNTU_APT_SNAPSHOT}" install -y --no-install-recommends \
        bash="${UBUNTU_APT_BASH_VERSION}" \
        ca-certificates="${UBUNTU_APT_CA_CERTIFICATES_VERSION}" \
        ceph-common="${UBUNTU_APT_CEPH_COMMON_VERSION}" \
        cifs-utils="${UBUNTU_APT_CIFS_UTILS_VERSION}" \
        conntrack="${UBUNTU_APT_CONNTRACK_VERSION}" \
        curl="${UBUNTU_APT_CURL_VERSION}" \
        ethtool="${UBUNTU_APT_ETHTOOL_VERSION}" \
        file="${UBUNTU_APT_FILE_VERSION}" \
        git="${UBUNTU_APT_GIT_VERSION}" \
        glusterfs-client="${UBUNTU_APT_GLUSTERFS_CLIENT_VERSION}" \
        ipset="${UBUNTU_APT_IPSET_VERSION}" \
        iptables="${UBUNTU_APT_IPTABLES_VERSION}" \
        jq="${UBUNTU_APT_JQ_VERSION}" \
        netcat-openbsd="${UBUNTU_APT_NETCAT_OPENBSD_VERSION}" \
        nfs-common="${UBUNTU_APT_NFS_COMMON_VERSION}" \
        open-iscsi="${UBUNTU_APT_OPEN_ISCSI_VERSION}" \
        socat="${UBUNTU_APT_SOCAT_VERSION}" \
        unzip="${UBUNTU_APT_UNZIP_VERSION}" \
        util-linux="${UBUNTU_APT_UTIL_LINUX_VERSION}" \
        wget="${UBUNTU_APT_WGET_VERSION}" \
        xfsprogs="${UBUNTU_APT_XFSPROGS_VERSION}"; \
    test "${TARGETARCH}" = "amd64"; \
    curl -fsSL --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 10 --max-time 600 \
        -o /tmp/azure-cli.deb "https://packages.microsoft.com/repos/azure-cli/pool/main/a/azure-cli/azure-cli_${AZURE_CLI_DEB_VERSION}_amd64.deb"; \
    echo "${AZURE_CLI_DEB_SHA256}  /tmp/azure-cli.deb" | sha256sum -c -; \
    apt-get --snapshot "${UBUNTU_APT_SNAPSHOT}" install -y --no-install-recommends /tmp/azure-cli.deb; \
    test "$(dpkg-query -W -f='${Version}' azure-cli)" = "${AZURE_CLI_DEB_VERSION}"; \
    cryptography_wheel="/tmp/cryptography-${CRYPTOGRAPHY_VERSION}-cp311-abi3-manylinux_2_34_x86_64.whl"; \
    pyopenssl_wheel="/tmp/pyopenssl-${PYOPENSSL_VERSION}-py3-none-any.whl"; \
    curl -fsSL --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 10 --max-time 300 \
        -o "${cryptography_wheel}" "https://files.pythonhosted.org/packages/9f/13/8b765e2e12b07c74941caadb9d1c8fdc006c4dfbf2b8f2d610519758954d/cryptography-${CRYPTOGRAPHY_VERSION}-cp311-abi3-manylinux_2_34_x86_64.whl"; \
    curl -fsSL --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 10 --max-time 300 \
        -o "${pyopenssl_wheel}" "https://files.pythonhosted.org/packages/73/b8/a0e2790ae249d6f38c9f66de7a211621a7ab2650217bcd04e1262f578a56/pyopenssl-${PYOPENSSL_VERSION}-py3-none-any.whl"; \
    echo "${CRYPTOGRAPHY_WHEEL_SHA256}  ${cryptography_wheel}" | sha256sum -c -; \
    echo "${PYOPENSSL_WHEEL_SHA256}  ${pyopenssl_wheel}" | sha256sum -c -; \
    /opt/az/bin/python3 -m pip install --no-cache-dir --no-index --no-deps --upgrade \
        "${cryptography_wheel}" \
        "${pyopenssl_wheel}"; \
    /opt/az/bin/python3 -c 'import cryptography, OpenSSL; assert cryptography.__version__ == "48.0.1"; assert OpenSSL.__version__ == "26.2.0"'; \
    /opt/az/bin/python3 -m pip check; \
    az version; \
    { \
        printf 'snapshot\t%s\n' "${UBUNTU_APT_SNAPSHOT}"; \
        dpkg-query -W -f='${binary:Package}\t${Version}\n' | LC_ALL=C sort; \
    } > /licenses/KUBERNETES-PACKAGE-UBUNTU-APT-PACKAGES.tsv; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/bin/pebble

COPY verify-azure-python-security /usr/local/bin/verify-azure-python-security
RUN /usr/local/bin/verify-azure-python-security

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

# The Dapper stage rebuilds this single CNI plug-in twice from the locked
# source commit with the reviewed Go toolchain before it enters this image.
COPY CNI-LICENSE /licenses/CNI-LICENSE
COPY loopback /opt/loopback/bin/loopback
RUN set -eux; \
    echo "${CNI_LICENSE_SHA256}  /licenses/CNI-LICENSE" | sha256sum -c -; \
    test -x /opt/loopback/bin/loopback

COPY update-platform-ca runc-1.10 utils.sh entry.sh addons-update.sh kubectl kubelet kube-proxy kube-apiserver kube-controller-manager kube-scheduler /usr/bin/
COPY kubernetes/cluster/addons /etc/kubernetes/addons/
COPY LICENSE SECURITY.md ORIGIN.md COMPATIBILITY.md /licenses/

ENTRYPOINT ["/usr/bin/entry.sh"]
