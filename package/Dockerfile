FROM golang:1.27.0-bookworm@sha256:484ef6066fa69acb059fdfeda7ba2b8f7391f2ef6abc6f9b8411e669ebd56466 AS kubernetes-builder

ARG KUBERNETES_VERSION=v1.36.4
ARG KUBERNETES_GIT_COMMIT=bb826b1d48562f110659e64e8ec444327433db95
ARG KUBERNETES_SOURCE_SHA256=3c28f11492472df48e658551bf268fd92938b127b0f9dcef7090ac800318c821
ARG KUBERNETES_LICENSE_SHA256=cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30
ARG OPENTELEMETRY_VERSION=v1.45.0
ARG OPENTELEMETRY_GRPC_VERSION=v0.70.0
ARG GRPC_GO_VERSION=v1.83.2
ARG CEL_GO_VERSION=v0.32.0
ARG ETCD_VERSION=v3.7.1
ARG ETCD_RAFT_VERSION=v3.7.0
ARG X_CRYPTO_VERSION=v0.56.0
ARG X_SYS_VERSION=v0.47.0
ENV GOMAXPROCS=2 GOTELEMETRY=off GOTOOLCHAIN=local

RUN set -eux; \
    test "$(go version)" = "go version go1.27.0 linux/amd64"; \
    mkdir -p /src/kubernetes /out/buildinfo; \
    curl --proto '=https' --tlsv1.2 --fail --silent --show-error --location \
        --output /tmp/kubernetes-source.tar.gz "https://dl.k8s.io/${KUBERNETES_VERSION}/kubernetes-src.tar.gz"; \
    echo "${KUBERNETES_SOURCE_SHA256}  /tmp/kubernetes-source.tar.gz" | sha256sum -c -; \
    tar -xzf /tmp/kubernetes-source.tar.gz -C /src/kubernetes; \
    rm -f /tmp/kubernetes-source.tar.gz; \
    cd /src/kubernetes; \
    echo "${KUBERNETES_LICENSE_SHA256}  LICENSE" | sha256sum -c -; \
    grep -RIlZ --exclude-dir=vendor --exclude='go.sum' 'github.com/google/cel-go' . \
        | xargs -0 -r sed -i 's#github.com/google/cel-go#cel.dev/cel-go#g'; \
    find . -path '*/vendor' -prune -o -name go.mod -type f -exec \
        sed -i -E "s#cel.dev/cel-go v[0-9]+\.[0-9]+\.[0-9]+#cel.dev/cel-go ${CEL_GO_VERSION}#g" {} +; \
    test -z "$(grep -RIl --exclude-dir=vendor --exclude='go.sum' 'github.com/google/cel-go' .)"; \
    GOWORK=off GOPROXY=https://proxy.golang.org GOSUMDB=sum.golang.org go get \
        "go.opentelemetry.io/otel@${OPENTELEMETRY_VERSION}" \
        "go.opentelemetry.io/otel/metric@${OPENTELEMETRY_VERSION}" \
        "go.opentelemetry.io/otel/sdk@${OPENTELEMETRY_VERSION}" \
        "go.opentelemetry.io/otel/trace@${OPENTELEMETRY_VERSION}" \
        "go.opentelemetry.io/otel/exporters/otlp/otlptrace@${OPENTELEMETRY_VERSION}" \
        "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc@${OPENTELEMETRY_VERSION}" \
        "go.opentelemetry.io/contrib/instrumentation/google.golang.org/grpc/otelgrpc@${OPENTELEMETRY_GRPC_VERSION}" \
        "google.golang.org/grpc@${GRPC_GO_VERSION}" \
        "cel.dev/cel-go@${CEL_GO_VERSION}" \
        "go.etcd.io/etcd/api/v3@${ETCD_VERSION}" \
        "go.etcd.io/etcd/client/pkg/v3@${ETCD_VERSION}" \
        "go.etcd.io/etcd/client/v3@${ETCD_VERSION}" \
        "go.etcd.io/etcd/pkg/v3@${ETCD_VERSION}" \
        "go.etcd.io/etcd/server/v3@${ETCD_VERSION}" \
        "go.etcd.io/etcd/etcdutl/v3@${ETCD_VERSION}" \
        "go.etcd.io/raft/v3@${ETCD_RAFT_VERSION}" \
        "golang.org/x/crypto@${X_CRYPTO_VERSION}" \
        "golang.org/x/sys@${X_SYS_VERSION}"; \
    GOWORK=off GOPROXY=https://proxy.golang.org GOSUMDB=sum.golang.org go mod tidy; \
    GOWORK=off GOPROXY=https://proxy.golang.org GOSUMDB=sum.golang.org go mod vendor; \
    test "$(GOWORK=off go list -m -f '{{.Version}}' go.opentelemetry.io/otel/sdk)" = "${OPENTELEMETRY_VERSION}"; \
    test "$(GOWORK=off go list -m -f '{{.Version}}' go.opentelemetry.io/contrib/instrumentation/google.golang.org/grpc/otelgrpc)" = "${OPENTELEMETRY_GRPC_VERSION}"; \
    test "$(GOWORK=off go list -m -f '{{.Version}}' google.golang.org/grpc)" = "${GRPC_GO_VERSION}"; \
    test "$(GOWORK=off go list -m -f '{{.Version}}' cel.dev/cel-go)" = "${CEL_GO_VERSION}"; \
    test "$(GOWORK=off go list -m -f '{{.Version}}' go.etcd.io/etcd/client/pkg/v3)" = "${ETCD_VERSION}"; \
    test "$(GOWORK=off go list -m -f '{{.Version}}' go.etcd.io/raft/v3)" = "${ETCD_RAFT_VERSION}"; \
    test "$(GOWORK=off go list -m -f '{{.Version}}' golang.org/x/crypto)" = "${X_CRYPTO_VERSION}"; \
    test "$(GOWORK=off go list -m -f '{{.Version}}' golang.org/x/sys)" = "${X_SYS_VERSION}"; \
    : > /out/buildinfo/OPENPGP-REACHABILITY.txt; \
    for package in cmd/kubeadm cmd/kubelet cmd/kube-proxy cmd/kube-apiserver cmd/kube-controller-manager cmd/kube-scheduler cmd/kubectl; do \
        if GOWORK=off go list -mod=vendor -deps "./${package}" | grep -Eq '^golang.org/x/crypto/openpgp(/|$)'; then \
            echo "deprecated OpenPGP package is reachable from ${package}" >&2; \
            exit 1; \
        fi; \
        printf '%s openpgp-package-count=0\n' "${package}" >> /out/buildinfo/OPENPGP-REACHABILITY.txt; \
    done; \
    CGO_ENABLED=0 GO_VERSION=1.27.0 FORCE_HOST_GO=1 KUBE_BUILD_PLATFORMS=linux/amd64 \
        KUBE_GIT_VERSION="${KUBERNETES_VERSION}" KUBE_GIT_COMMIT="${KUBERNETES_GIT_COMMIT}" \
        KUBE_GIT_TREE_STATE=clean KUBE_GIT_MAJOR=1 KUBE_GIT_MINOR=36 \
        ./hack/make-rules/build.sh \
            cmd/kubeadm cmd/kubelet cmd/kube-proxy cmd/kube-apiserver \
            cmd/kube-controller-manager cmd/kube-scheduler cmd/kubectl; \
    for binary in kubeadm kubelet kube-proxy kube-apiserver kube-controller-manager kube-scheduler kubectl; do \
        install -m 0555 "_output/local/go/bin/${binary}" "/out/${binary}"; \
        go version -m "/out/${binary}" > "/out/buildinfo/${binary}.txt"; \
        grep -Fq "/out/${binary}: go1.27.0" "/out/buildinfo/${binary}.txt"; \
    done; \
    test "$(/out/kubeadm version -o short)" = "${KUBERNETES_VERSION}"; \
    for binary in kubelet kube-proxy kube-apiserver kube-controller-manager kube-scheduler; do \
        test "$(/out/${binary} --version)" = "Kubernetes ${KUBERNETES_VERSION}"; \
    done; \
    /out/kubectl version --client=true --output=json | grep -Fq "\"gitVersion\": \"${KUBERNETES_VERSION}\""; \
    install -m 0444 LICENSE /out/KUBERNETES-LICENSE; \
    rm -rf /src/kubernetes /root/.cache/go-build /tmp/go-build*

FROM golang:1.27.0-bookworm@sha256:484ef6066fa69acb059fdfeda7ba2b8f7391f2ef6abc6f9b8411e669ebd56466 AS cni-builder

ARG CNI_VERSION=v1.9.1
ARG CNI_GIT_COMMIT=adc3e6b5b581638afbd194cf2e9319ecbb0151a1
ARG CNI_GIT_TREE=91451a8931a305da27de4df81662ec08af58249e
ARG CNI_LICENSE_SHA256=b40930bbcf80744c86c46a12bc9da056641d722716c378f5659b9e555ef833e1
ARG X_SYS_VERSION=v0.47.0
ENV GOMAXPROCS=2 GOTELEMETRY=off GOTOOLCHAIN=local

RUN set -eux; \
    test "$(go version)" = "go version go1.27.0 linux/amd64"; \
    mkdir -p /out; \
    git init -q /src/cni; \
    cd /src/cni; \
    git remote add origin https://github.com/containernetworking/plugins.git; \
    git fetch -q --depth=1 --no-tags origin "refs/tags/${CNI_VERSION}"; \
    git checkout -q --detach FETCH_HEAD; \
    test "$(git rev-parse HEAD)" = "${CNI_GIT_COMMIT}"; \
    test "$(git rev-parse 'HEAD^{tree}')" = "${CNI_GIT_TREE}"; \
    echo "${CNI_LICENSE_SHA256}  LICENSE" | sha256sum -c -; \
    GOPROXY=https://proxy.golang.org GOSUMDB=sum.golang.org go get "golang.org/x/sys@${X_SYS_VERSION}"; \
    GOPROXY=https://proxy.golang.org GOSUMDB=sum.golang.org go mod vendor; \
    test "$(go list -m -f '{{.Version}}' golang.org/x/sys)" = "${X_SYS_VERSION}"; \
    CGO_ENABLED=0 GOPROXY=off go test -mod=vendor -run '^$' ./plugins/main/loopback; \
    CGO_ENABLED=0 GOPROXY=off go build -mod=vendor -trimpath -buildvcs=false \
        -ldflags "-s -w -buildid= -X github.com/containernetworking/plugins/pkg/utils/buildversion.BuildVersion=${CNI_VERSION}" \
        -o /out/loopback ./plugins/main/loopback; \
    /out/loopback 2>&1 | grep -Fq "CNI loopback plugin ${CNI_VERSION}"; \
    CNI_COMMAND=VERSION /out/loopback | grep -Fq '"supportedVersions"'; \
    go version -m /out/loopback > /out/CNI-LOOPBACK-BUILDINFO.txt; \
    grep -Fq '/out/loopback: go1.27.0' /out/CNI-LOOPBACK-BUILDINFO.txt; \
    install -m 0444 LICENSE /out/CNI-LICENSE; \
    chmod 0555 /out/loopback; \
    rm -rf /src/cni /root/.cache/go-build /tmp/go-build*

FROM scratch

ARG IMAGE_VERSION=dev
ARG SOURCE_REVISION=unknown
ARG KUBERNETES_VERSION=v1.36.4
ARG KUBERNETES_GIT_COMMIT=bb826b1d48562f110659e64e8ec444327433db95
ARG KUBERNETES_SOURCE_SHA256=3c28f11492472df48e658551bf268fd92938b127b0f9dcef7090ac800318c821
ARG OPENTELEMETRY_VERSION=v1.45.0
ARG OPENTELEMETRY_GRPC_VERSION=v0.70.0
ARG GRPC_GO_VERSION=v1.83.2
ARG CEL_GO_VERSION=v0.32.0
ARG ETCD_VERSION=v3.7.1
ARG ETCD_RAFT_VERSION=v3.7.0
ARG X_CRYPTO_VERSION=v0.56.0
ARG X_SYS_VERSION=v0.47.0
ARG CNI_VERSION=v1.9.1
ARG CNI_GIT_COMMIT=adc3e6b5b581638afbd194cf2e9319ecbb0151a1
ARG CNI_GIT_TREE=91451a8931a305da27de4df81662ec08af58249e

COPY --from=kubernetes-builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=kubernetes-builder \
    /out/kubeadm /out/kubelet /out/kube-proxy /out/kube-apiserver \
    /out/kube-controller-manager /out/kube-scheduler /out/kubectl /usr/bin/
COPY --from=kubernetes-builder /out/buildinfo/ /licenses/kubernetes-buildinfo/
COPY --from=kubernetes-builder /out/KUBERNETES-LICENSE /licenses/KUBERNETES-LICENSE
COPY --from=cni-builder /out/loopback /opt/cni/bin/loopback
COPY --from=cni-builder /out/CNI-LICENSE /out/CNI-LOOPBACK-BUILDINFO.txt /licenses/
COPY LICENSE SECURITY.md ORIGIN.md COMPATIBILITY.md /licenses/pasturestack/

ENV PATH=/usr/bin:/opt/cni/bin \
    SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
    KUBECONFIG=/etc/kubernetes/admin.conf

LABEL org.opencontainers.image.source="https://github.com/PastureStack/kubernetes-package" \
      org.opencontainers.image.title="pasturestack-kubernetes-package" \
      org.opencontainers.image.description="Current upstream Kubernetes component and CNI bundle" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.opencontainers.image.revision="${SOURCE_REVISION}" \
      org.opencontainers.image.licenses="Apache-2.0" \
      io.pasturestack.kubernetes.version="${KUBERNETES_VERSION}" \
      io.pasturestack.kubernetes.revision="${KUBERNETES_GIT_COMMIT}" \
      io.pasturestack.kubernetes.source-sha256="${KUBERNETES_SOURCE_SHA256}" \
      io.pasturestack.dependencies.opentelemetry="${OPENTELEMETRY_VERSION}" \
      io.pasturestack.dependencies.opentelemetry-grpc="${OPENTELEMETRY_GRPC_VERSION}" \
      io.pasturestack.dependencies.grpc-go="${GRPC_GO_VERSION}" \
      io.pasturestack.dependencies.cel-go="${CEL_GO_VERSION}" \
      io.pasturestack.dependencies.etcd="${ETCD_VERSION}" \
      io.pasturestack.dependencies.etcd-raft="${ETCD_RAFT_VERSION}" \
      io.pasturestack.dependencies.x-crypto="${X_CRYPTO_VERSION}" \
      io.pasturestack.dependencies.x-sys="${X_SYS_VERSION}" \
      io.pasturestack.cni.version="${CNI_VERSION}" \
      io.pasturestack.cni.revision="${CNI_GIT_COMMIT}" \
      io.pasturestack.cni.tree="${CNI_GIT_TREE}" \
      io.pasturestack.tools.compiler="go1.27.0" \
      io.pasturestack.runtime.base="scratch" \
      io.pasturestack.cloud-provider="external-required" \
      io.pasturestack.legacy-rancher16-compatible="false"

CMD ["/usr/bin/kubectl", "version", "--client=true", "--output=json"]
