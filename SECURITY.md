# Security Policy

## Maintained scope

Only the Kubernetes `v1.36.4` component bundle and CNI loopback `v1.9.1` payload described in the root README are maintained. Historical Kubernetes, Helm/Tiller, kube-dns, Azure CLI, Docker-shim, Rancher metadata, and add-on code remain available only through Git history and are not security-supported runtime paths.

## Supply-chain requirements

- Build Kubernetes from the official `v1.36.4` source archive and verify both its SHA-256 and upstream license before compilation.
- Bind Kubernetes version metadata to upstream commit `bb826b1d48562f110659e64e8ec444327433db95` and compile every shipped Go binary with Go `1.27.0`.
- Migrate the former GitHub CEL import path to its current `cel.dev/cel-go` module, upgrade the source graph to the recorded current CEL-Go, etcd, OpenTelemetry, gRPC-Go, `x/crypto`, and `x/sys` versions, then regenerate it through the public Go module proxy and checksum database.
- Build CNI loopback from official plug-ins `v1.9.1`, verify the exact tag commit, Git tree and license SHA-256, and update its `x/sys` graph through the same authenticated module path before compiling offline from vendor.
- Build every shipped executable statically and use a `scratch` runtime. No package manager, shell, general-purpose utility suite, or mutable runtime base is permitted.
- Fail the candidate on any actionable vulnerability at any severity or any detected secret. Publish both the unfiltered raw Trivy result and the VEX-aware result with the CycloneDX SBOM.
- Permit VEX only when a deterministic source-graph gate proves the vulnerable package is absent. `GO-2026-5932` is bound specifically to the discontinued `x/crypto/openpgp` package; the build fails if that package becomes reachable from any shipped command.

## Runtime boundary

The default command is a read-only client version query. The image has no shell. `kubelet`, `kube-proxy`, `kubeadm`, and control-plane servers can require root privileges, host utilities, and sensitive host mounts; operators must supply and grant only the exact capabilities and paths required by their deployment. The image does not start a component, connect to a cluster, alter host state, or install add-ons by itself.

Cloud integrations must use maintained external cloud-controller-manager and CSI projects. A supported CRI, etcd, complete CNI, DNS service, certificates, admission policy, network policy, and backup/restore design remain deployment responsibilities.

## Reporting

Report suspected vulnerabilities privately through the repository security advisory channel. Include the source revision, image ID or registry digest, component command, and a minimal reproduction. Do not include cluster credentials, kubeconfig files, certificates, tokens, or production data.
