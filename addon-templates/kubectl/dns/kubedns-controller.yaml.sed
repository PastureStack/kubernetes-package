# Copyright 2016 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Should keep target in cluster/addons/dns-horizontal-autoscaler/dns-horizontal-autoscaler.yaml
# in sync with this file.

# Warning: This is a file generated from the base underscore template file: kubedns-controller.yaml.base
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: kube-dns
  namespace: kube-system
  labels:
    k8s-app: kube-dns
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
spec:
  replicas: $DNS_REPLICAS
  strategy:
    rollingUpdate:
      maxSurge: 10%
      maxUnavailable: 0
  selector:
    matchLabels:
      k8s-app: kube-dns
  template:
    metadata:
      labels:
        k8s-app: kube-dns
        $DNS_APP_LABEL_KEY: cluster-dns
      annotations:
        scheduler.alpha.kubernetes.io/critical-pod: ''
    spec:
      tolerations:
      - key: "CriticalAddonsOnly"
        operator: "Exists"
      volumes:
      - name: kube-dns-config
        configMap:
          name: kube-dns
          optional: true
      affinity:
        podAntiAffinity:
          # Prefer separate hosts for availability, but permit a same-host
          # surge so a one-node cluster can complete a rolling update.
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: $DNS_APP_LABEL_KEY
                  operator: In
                  values:
                  - cluster-dns
              topologyKey: kubernetes.io/hostname
      containers:
      - name: kubedns
        image: $DNS_IMAGE_REGISTRY/$DNS_IMAGE_NAMESPACE/$CLUSTER_DNS_IMAGE
        imagePullPolicy: IfNotPresent
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 65532
          capabilities:
            drop:
            - ALL
        resources:
          # TODO: Set memory limits when we've profiled the container for large
          # clusters, then set request = limit to keep this container in
          # guaranteed class. Currently, this container falls into the
          # "burstable" category so the kubelet doesn't backoff from restarting it.
          limits:
            memory: 170Mi
          requests:
            cpu: 100m
            memory: 70Mi
        livenessProbe:
          httpGet:
            path: /readiness
            port: 8081
            scheme: HTTP
          # Initial synchronization is bounded at 60 seconds; do not let the
          # liveness probe restart the process while that first list is active.
          initialDelaySeconds: 75
          timeoutSeconds: 2
          successThreshold: 1
          failureThreshold: 3
          periodSeconds: 2
        readinessProbe:
          httpGet:
            path: /readiness
            port: 8081
            scheme: HTTP
          # we poll on pod startup for the Kubernetes master service and
          # only setup the /readiness HTTP server once that's available.
          initialDelaySeconds: 3
          timeoutSeconds: 2
          successThreshold: 1
          failureThreshold: 3
          periodSeconds: 2
        args:
        - --domain=$DNS_DOMAIN.
        - --dns-port=10053
        - --config-dir=/kube-dns-config
        - --initial-sync-timeout=60s
        - --v=$ADDONS_LOG_VERBOSITY_LEVEL
        env:
        # Kubernetes 1.12 does not provide the initial-event bookmark required
        # by newer client-go WatchList clients. Use the supported list/watch path.
        - name: KUBE_FEATURE_WatchListClient
          value: "false"
        - name: PROMETHEUS_PORT
          value: "10055"
        ports:
        - containerPort: 10053
          name: dns-local
          protocol: UDP
        - containerPort: 10053
          name: dns-tcp-local
          protocol: TCP
        - containerPort: 10055
          name: metrics
          protocol: TCP
        - containerPort: 8081
          name: status
          protocol: TCP
        volumeMounts:
        - name: kube-dns-config
          mountPath: /kube-dns-config
      dnsPolicy: Default  # Don't use cluster DNS.
      serviceAccountName: $DNS_SERVICE_ACCOUNT
