# Compatibility Contract

The migration preserves the Kubernetes 1.12-era binary layout, kubeconfig and certificate paths, metadata endpoints, API credentials, control-plane command arguments, add-on manifests, service-account and label identifiers, and host mount behavior required by recorded deployments.

Preferred settings and service names use `PLATFORM_*`, `metadata`, `kubernetes-authentication-bridge`, and the `pasturestack` image namespace. Historical `CATTLE_*`, `RANCHER_*`, `io.rancher.*`, `rancher-app`, service-account names, cloud-provider identifiers, internal DNS names, external artifact tags, and API resource names remain only where they are compatibility contracts.

Historical artifact tags containing an upstream vendor suffix are immutable external version identities. Renaming them would make source provenance false. A future PastureStack-built artifact must use a new version and its own independently verified source and checksums.

Operator wait-state messages support `en-US` and `zh-TW`. Kubernetes YAML, API values, credentials, identifiers, labels, kubeconfigs, and command output are never translated.

Before release, validate every role, certificate flow, metadata lookup, authentication webhook, add-on rendering, Docker API compatibility override, cgroup and mount path, control-plane startup, worker join, upgrade, and rollback in an isolated VM.

The Helm 2 compatibility server and client are aligned at v2.17.0. The add-on
manager uses a rolling Deployment update, retains ConfigMap and Secret release
records, compares their canonical metadata and payload content, and restores
the previous Deployment revision when readiness or record verification fails.
Operators must also create and verify an offline bundle with
`scripts/tiller-release-backup` before any cluster upgrade. This path does not
run `helm init --upgrade`, restore or convert release storage, delete workloads,
or claim Helm 3 compatibility.
