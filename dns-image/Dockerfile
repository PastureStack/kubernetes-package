FROM gcr.io/distroless/static-debian12@sha256:4b2a093ef4649bccd586625090a3c668b254cfe180dee54f4c94f3e9bd7e381e

ARG IMAGE_VERSION
ARG SOURCE_REVISION
ARG UPSTREAM_REVISION

LABEL org.opencontainers.image.source="https://github.com/PastureStack/kubernetes-package" \
      org.opencontainers.image.title="PastureStack cluster DNS" \
      org.opencontainers.image.description="Kubernetes 1.12-compatible cluster DNS service" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.opencontainers.image.revision="${SOURCE_REVISION}" \
      org.opencontainers.image.licenses="Apache-2.0" \
      io.pasturestack.third-party-licenses="/licenses/cluster-dns-third-party" \
      io.pasturestack.upstream.repository="https://github.com/kubernetes/dns" \
      io.pasturestack.upstream.revision="${UPSTREAM_REVISION}"

COPY --chown=65532:65532 cluster-dns /cluster-dns
COPY --chown=65532:65532 LICENSE.kubernetes-dns /licenses/LICENSE.kubernetes-dns
COPY --chown=65532:65532 third-party-licenses /licenses/cluster-dns-third-party

# Kubernetes 1.12 predates WatchList initial-event bookmarks. Keep client-go on
# its supported list-then-watch path so initial DNS synchronization completes.
ENV KUBE_FEATURE_WatchListClient=false

USER 65532:65532
ENTRYPOINT ["/cluster-dns"]
