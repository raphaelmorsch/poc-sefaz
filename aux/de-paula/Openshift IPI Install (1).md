## Passos de instalação

- [ ] Instalar OpenShift
- [ ] Criar MachineSet para Infra-Nodes
- [ ] Mover Registry e Router para Infra nodes
- [ ] Mover stack de monitoracao para Infra Nodes
- [ ] Marcar master-nodes como schedulable (opcional)
- [ ] Criar MachineSet para Logging Stack (se necessário)
- [ ] Realizar o deploy do Logging
- [ ] Alocar logging nos Infra Nodes
- [ ] Configurar storage do Registry (EmptyDir/PVC)
- [ ] Criar Machine Health Check
- [ ] Configurar autenticação
- [ ] Criar novos StorageClasses em Datastore diferente

# Openshift IPI

## Issues

* If using F5 Load Balancer in L7 mode needs to relay the SNI from Client Hello to the Openshift router.

## Install config

```yaml
apiVersion: v1
baseDomain: internal.carlosedp.com
compute:
- architecture: amd64
  hyperthreading: Enabled
  name: worker
  platform:
    vsphere:
      coresPerSocket: 2
      cpus: 2
      memoryMB: 4096
      osDisk:
        diskSizeGB: 60
  replicas: 2
controlPlane:
  architecture: amd64
  hyperthreading: Enabled
  name: master
  platform:
    vsphere:
      coresPerSocket: 2
      cpus: 6
      memoryMB: 16384
      osDisk:
        diskSizeGB: 60
  replicas: 3
metadata:
  creationTimestamp: null
  name: ocp
networking:
  clusterNetwork:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  machineNetwork:
  - cidr: 192.168.1.0/24
  networkType: OpenShiftSDN
  serviceNetwork:
  - 172.30.0.0/16
platform:
  vsphere:
    apiVIP: 192.168.1.30
    cluster: Cluster
    datacenter: Datacenter
    defaultDatastore: VMs-02-960GB-SSD
    ingressVIP: 192.168.1.31
    network: DPortGroup
    password: Openshift#123
    username: openshift@internal.carlosedp.com
    vCenter: vcenter.internal.carlosedp.com
    diskType: thin
publish: External
pullSecret: 
```

## Additional Configs (if required)
### Create Infra MachineSet

```yaml
apiVersion: machine.openshift.io/v1beta1
kind: MachineSet
metadata:
  labels:
    machine.openshift.io/cluster-api-cluster: ocp-9s46k
  name: ocp-9s46k-infra
  namespace: openshift-machine-api
spec:
  replicas: 2
  selector:
    matchLabels:
      machine.openshift.io/cluster-api-cluster: ocp-9s46k
      machine.openshift.io/cluster-api-machineset: ocp-9s46k-infra
  template:
    metadata:
      labels:
        machine.openshift.io/cluster-api-cluster: ocp-9s46k
        machine.openshift.io/cluster-api-machine-role: infra
        machine.openshift.io/cluster-api-machine-type: infra
        machine.openshift.io/cluster-api-machineset: ocp-9s46k-infra
    spec:
      metadata:
        labels:
          node-role.kubernetes.io/infra: ""
      taints:
      - effect: NoSchedule
        key: infra
        value: reserved
      - effect: NoExecute
        key: infra
        value: reserved
      providerSpec:
        value:
          apiVersion: vsphereprovider.openshift.io/v1beta1
          credentialsSecret:
            name: vsphere-cloud-credentials
          diskGiB: 60
          kind: VSphereMachineProviderSpec
          memoryMiB: 8192
          metadata:
            creationTimestamp: null
          network:
            devices:
            - networkName: DPortGroup
          numCPUs: 4
          numCoresPerSocket: 2
          snapshot: ""
          template: ocp-9s46k-rhcos
          userDataSecret:
            name: worker-user-data
          workspace:
            datacenter: Datacenter
            datastore: VMs-02-960GB-SSD
            folder: /Datacenter/vm/ocp-9s46k
            resourcePool: /Datacenter/host/Cluster/Resources
            server: vcenter.internal.carlosedp.com
```

Mark Infra Nodes as non-schedulable for infra-only workloads (optional)

```sh
# No need to do this since the MachineSet already sets the taints
oc adm taint nodes -l node-role.kubernetes.io/infra infra=reserved:NoSchedule infra=reserved:NoExecute

# Allow operator daemonset on these nodes
oc patch ds machine-config-daemon -n openshift-machine-config-operator --type=merge -p '{"spec": {"template": { "spec": {"tolerations":[{"operator":"Exists"}]}}}}'
```


### Move Registry and Router to Infra nodes

Routers

```sh
oc patch ingresscontroller/default -n openshift-ingress-operator --type=merge -p '{"spec":{"nodePlacement": {"nodeSelector": {"matchLabels": {"node-role.kubernetes.io/infra": ""}},"tolerations": [{"effect":"NoSchedule","key": "infra","value": "reserved"},{"effect":"NoExecute","key": "infra","value": "reserved"}]}}}'

oc patch ingresscontroller default -n openshift-ingress-operator --type=merge --patch='{"spec":{"replicas": 2}}'
```

Registry 

```sh
oc patch configs.imageregistry.operator.openshift.io/cluster -n openshift-image-registry --type=merge -p '{"spec":{"nodeSelector": {"node-role.kubernetes.io/infra": ""},"tolerations": [{"effect":"NoSchedule","key": "infra","value": "reserved"},{"effect":"NoExecute","key": "infra","value": "reserved"}]}}'

oc patch configs.imageregistry.operator.openshift.io/cluster -n openshift-image-registry --type=merge --patch='{"spec":{"replicas": 2}}'
```

### Move Monitoring stack to Infra nodes and add persistent storage

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
 name: cluster-monitoring-config
 namespace: openshift-monitoring
data:
 config.yaml: |+
   alertmanagerMain:
     volumeClaimTemplate:
       metadata:
         name: pvc-alertmanager
       spec:
         storageClassName: thin
         resources:
           requests:
             storage: 1Gi
     nodeSelector:
       node-role.kubernetes.io/infra: ""
     tolerations:
     - key: infra
       value: reserved
       effect: NoSchedule
     - key: infra
       value: reserved
       effect: NoExecute
   prometheusK8s:
     volumeClaimTemplate:
       metadata:
         name: pvc-prometheus
       spec:
         storageClassName: thin
         resources:
           requests:
             storage: 10Gi
     nodeSelector:
       node-role.kubernetes.io/infra: ""
     tolerations:
     - key: infra
       value: reserved
       effect: NoSchedule
     - key: infra
       value: reserved
       effect: NoExecute
   prometheusOperator:
     nodeSelector:
       node-role.kubernetes.io/infra: ""
     tolerations:
     - key: infra
       value: reserved
       effect: NoSchedule
     - key: infra
       value: reserved
       effect: NoExecute
   grafana:
     nodeSelector:
       node-role.kubernetes.io/infra: ""
     tolerations:
     - key: infra
       value: reserved
       effect: NoSchedule
     - key: infra
       value: reserved
       effect: NoExecute
   k8sPrometheusAdapter:
     nodeSelector:
       node-role.kubernetes.io/infra: ""
     tolerations:
     - key: infra
       value: reserved
       effect: NoSchedule
     - key: infra
       value: reserved
       effect: NoExecute
   kubeStateMetrics:
     nodeSelector:
       node-role.kubernetes.io/infra: ""
     tolerations:
     - key: infra
       value: reserved
       effect: NoSchedule
     - key: infra
       value: reserved
       effect: NoExecute
   telemeterClient:
     nodeSelector:
       node-role.kubernetes.io/infra: ""
     tolerations:
     - key: infra
       value: reserved
       effect: NoSchedule
     - key: infra
       value: reserved
       effect: NoExecute
   openshiftStateMetrics:
     nodeSelector:
       node-role.kubernetes.io/infra: ""
     tolerations:
     - key: infra
       value: reserved
       effect: NoSchedule
     - key: infra
       value: reserved
       effect: NoExecute
   thanosQuerier:
     nodeSelector:
       node-role.kubernetes.io/infra: ""
     tolerations:
     - key: infra
       value: reserved
       effect: NoSchedule
     - key: infra
       value: reserved
       effect: NoExecute
```

Apply to cluster

```sh
oc create -f cluster-monitoring-configmap.yaml -n openshift-monitoring
```

### Misc

Set masters to schedulable

```sh
oc patch schedulers.config.openshift.io cluster --type merge --patch '{"spec":{"mastersSchedulable": true}}'
```

### Registry

Registry storage PV/PVC.

### Using NFS

Configure server with:

```sh
# cat /etc/exports
/mnt/data *(rw,sync,no_wdelay,root_squash,insecure,fsid=0)

# exportfs -rv
```

Deploy PV/PVC:

```yaml
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: image-registry-pv
spec:
  accessModes:
    - ReadWriteMany
  capacity:
      storage: 100Gi
  nfs:
    path: /nfs-data
    server: 192.168.1.20
  persistentVolumeReclaimPolicy: Retain
  storageClassName: nfs01
---
apiVersion: "v1"
kind: "PersistentVolumeClaim"
metadata:
  name: "image-registry-pvc"
  namespace: openshift-image-registry
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 100Gi
  storageClassName: nfs01
  volumeMode: Filesystem
```

Patch operator:

```bash
oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"storage": {"pvc": {"claim": "image-registry-pvc"}}}}'
oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"managementState":"Managed"}}'
```

### Using Object Storage with Minio

Minio template:

```yaml
MINIO_SECRET_KEY=mysecret
apiVersion: template.openshift.io/v1
kind: Template
labels:
  app: minio
  template: minio
message: |-
  The following service(s) have been created in your project: ${NAME}.

  For more information about using this template, including OpenShift considerations, see https://github.com/elmanytas/minio-openshift/blob/master/README.md.
metadata:
  annotations:
    description: |-
      A min.io service.  For more information about using this template, including OpenShift considerations, see https://github.com/elmanytas/minio-openshift/blob/master/README.md.

      WARNING: This template needs a default storage class with space enough.
    iconClass: icon-database
    openshift.io/display-name: min.io
    openshift.io/documentation-url: https://github.com/elmanytas/minio-openshift
    openshift.io/long-description:
      This template defines resources needed to deploy
      a min.io service that allows you to use a AWS S3 compatible api in your apps.
    tags: minio,min.io,s3
    template.openshift.io/bindable: "false"
  name: minio
objects:
  - apiVersion: v1
    kind: Secret
    metadata:
      name: ${NAME}-keys
      namespace: ${NAMESPACE}
    stringData:
      access-key: ${MINIO_ACCESS_KEY}
      secret-key: ${MINIO_SECRET_KEY}
  - apiVersion: v1
    kind: Service
    metadata:
      annotations:
        description: Exposes the application pod
        service.alpha.openshift.io/dependencies: '[{"name": "${MINIO_SERVICE_NAME}", "kind": "Service"}]'
      name: ${NAME}
      namespace: ${NAMESPACE}
    spec:
      ports:
        - name: ${NAME}
          port: 9000
          targetPort: 9000
      selector:
        app: ${NAME}
  - apiVersion: v1
    kind: Route
    metadata:
      name: ${NAME}
      namespace: ${NAMESPACE}
    spec:
      host: ${APPLICATION_DOMAIN}
      to:
        kind: Service
        name: ${NAME}
  - apiVersion: apps/v1
    kind: StatefulSet
    metadata:
      labels:
        app: ${NAME}
      name: ${NAME}
      namespace: ${NAMESPACE}
    spec:
      podManagementPolicy: OrderedReady
      replicas: 1
      revisionHistoryLimit: 1
      selector:
        matchLabels:
          app: ${NAME}
      serviceName: ${NAME}
      template:
        metadata:
          creationTimestamp: null
          labels:
            app: ${NAME}
        spec:
          containers:
            - args:
                - server
                - /data
              env:
                - name: MINIO_ACCESS_KEY
                  valueFrom:
                    secretKeyRef:
                      key: access-key
                      name: ${NAME}-keys
                - name: MINIO_SECRET_KEY
                  valueFrom:
                    secretKeyRef:
                      key: secret-key
                      name: ${NAME}-keys
              image: minio/minio:latest
              imagePullPolicy: IfNotPresent
              name: ${NAME}
              ports:
                - containerPort: 9000
                  protocol: TCP
              resources:
                limits:
                  cpu: 200m
                  memory: ${MEMORY_LIMIT}
              terminationMessagePath: /dev/termination-log
              terminationMessagePolicy: File
              volumeMounts:
                - mountPath: /data
                  name: data
          dnsPolicy: ClusterFirst
          restartPolicy: Always
          schedulerName: default-scheduler
          securityContext: {}
          terminationGracePeriodSeconds: 30
      updateStrategy:
        type: OnDelete
      volumeClaimTemplates:
        - metadata:
            name: data
          spec:
            accessModes:
              - ReadWriteOnce
            resources:
              requests:
                storage: 10Gi
parameters:
  - description: The name assigned to all of the frontend objects defined in this template.
    displayName: Name
    name: NAME
    required: true
    value: minio
  - description: The project used for the application.
    displayName: Namespace
    name: NAMESPACE
    required: true
    value: minio
  - description: Maximum amount of memory the container can use.
    displayName: Memory Limit
    name: MEMORY_LIMIT
    required: true
    value: 512Mi
  - description:
      The exposed hostname that will route to the Min.io service, if left
      blank a value will be defaulted.
    displayName: Application Hostname
    name: APPLICATION_DOMAIN
  - description: Access key for min.io api.
    displayName: Access Key
    from: "[a-zA-Z0-9]{32}"
    generate: expression
    name: MINIO_ACCESS_KEY
  - description: Secret key for min.io api.
    displayName: Secret Key
    from: "[a-zA-Z0-9]{32}"
    generate: expression
    name: MINIO_SECRET_KEY
```

Create project and apply template:

```sh
oc new-project minio
oc new-app --namespace=minio -f minio-template.yaml -p MINIO_ACCESS_KEY=myaccesskey -p MINIO_SECRET_KEY=mysecretkey
```

Patch operator:

```bash
oc create secret generic image-registry-private-configuration-user --from-literal=REGISTRY_STORAGE_S3_ACCESSKEY=myaccesskey --from-literal=REGISTRY_STORAGE_S3_SECRETKEY=mysecretkey --namespace openshift-image-registry

oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"storage":{"s3":{"bucket":"registry","encrypt":false,"regionEndpoint":"http://minio-minio.apps.ocp.internal.carlosedp.com","region":"us-east-1"}}}}'
oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"managementState":"Managed"}}'
```

### Machine Health Check

```yaml
apiVersion: machine.openshift.io/v1beta1
kind: MachineHealthCheck
metadata:
  name: workers
  namespace: openshift-machine-api
spec:
  maxUnhealthy: 40%
  selector:
    matchLabels:
      machine.openshift.io/cluster-api-cluster: ocp-2fn76
      machine.openshift.io/cluster-api-machine-role: worker
      machine.openshift.io/cluster-api-machine-type: worker
      machine.openshift.io/cluster-api-machineset: ocp-2fn76-worker
  unhealthyConditions:
    - status: Unknown
      timeout: 300s
      type: Ready
    - status: 'False'
      timeout: 300s
      type: Ready
```

### Rotate certificates to shutdown VMs


Create Daemonset

```sh
cat << 'EOF' >kubelet-bootstrap-cred-manager-ds.yaml.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: kubelet-bootstrap-cred-manager
  namespace: openshift-machine-config-operator
  labels:
    k8s-app: kubelet-bootrap-cred-manager
spec:
  selector:
    matchLabels:
      k8s-app: kubelet-bootstrap-cred-manager
  template:
    metadata:
      labels:
        k8s-app: kubelet-bootstrap-cred-manager
    spec:
      containers:
      - name: kubelet-bootstrap-cred-manager
        image: quay.io/openshift/origin-cli:v4.0
        command: ['/bin/bash', '-ec']
        args:
          - |
            #!/bin/bash

            set -eoux pipefail

            while true; do
              unset KUBECONFIG

              echo "---------------------------------"
              echo "Gather info..."
              echo "---------------------------------"
              # context
              intapi=$(oc get infrastructures.config.openshift.io cluster -o "jsonpath={.status.apiServerInternalURI}")
              context="$(oc --config=/etc/kubernetes/kubeconfig config current-context)"
              # cluster
              cluster="$(oc --config=/etc/kubernetes/kubeconfig config view -o "jsonpath={.contexts[?(@.name==\"$context\")].context.cluster}")"
              server="$(oc --config=/etc/kubernetes/kubeconfig config view -o "jsonpath={.clusters[?(@.name==\"$cluster\")].cluster.server}")"
              # token
              ca_crt_data="$(oc get secret -n openshift-machine-config-operator node-bootstrapper-token -o "jsonpath={.data.ca\.crt}" | base64 --decode)"
              namespace="$(oc get secret -n openshift-machine-config-operator node-bootstrapper-token  -o "jsonpath={.data.namespace}" | base64 --decode)"
              token="$(oc get secret -n openshift-machine-config-operator node-bootstrapper-token -o "jsonpath={.data.token}" | base64 --decode)"

              echo "---------------------------------"
              echo "Generate kubeconfig"
              echo "---------------------------------"

              export KUBECONFIG="$(mktemp)"
              kubectl config set-credentials "kubelet" --token="$token" >/dev/null
              ca_crt="$(mktemp)"; echo "$ca_crt_data" > $ca_crt
              kubectl config set-cluster $cluster --server="$intapi" --certificate-authority="$ca_crt" --embed-certs >/dev/null
              kubectl config set-context kubelet --cluster="$cluster" --user="kubelet" >/dev/null
              kubectl config use-context kubelet >/dev/null

              echo "---------------------------------"
              echo "Print kubeconfig"
              echo "---------------------------------"
              cat "$KUBECONFIG"

              echo "---------------------------------"
              echo "Whoami?"
              echo "---------------------------------"
              oc whoami
              whoami

              echo "---------------------------------"
              echo "Moving to real kubeconfig"
              echo "---------------------------------"
              cp /etc/kubernetes/kubeconfig /etc/kubernetes/kubeconfig.prev
              chown root:root ${KUBECONFIG}
              chmod 0644 ${KUBECONFIG}
              mv "${KUBECONFIG}" /etc/kubernetes/kubeconfig

              echo "---------------------------------"
              echo "Sleep 60 seconds..."
              echo "---------------------------------"
              sleep 60
            done
        securityContext:
          privileged: true
          runAsUser: 0
        volumeMounts:
          - mountPath: /etc/kubernetes/
            name: kubelet-dir
      nodeSelector:
        node-role.kubernetes.io/master: ""
      priorityClassName: "system-cluster-critical"
      restartPolicy: Always
      securityContext:
        runAsUser: 0
      tolerations:
      - key: "node-role.kubernetes.io/master"
        operator: "Exists"
        effect: "NoSchedule"
      - key: "node.kubernetes.io/unreachable"
        operator: "Exists"
        effect: "NoExecute"
        tolerationSeconds: 120
      - key: "node.kubernetes.io/not-ready"
        operator: "Exists"
        effect: "NoExecute"
        tolerationSeconds: 120
      volumes:
        - hostPath:
            path: /etc/kubernetes/
            type: Directory
          name: kubelet-dir
EOF
```

Deploy the DaemonSet to your cluster.

```sh
oc apply -f kubelet-bootstrap-cred-manager-ds.yaml.yaml
```

Delete the secrets csr-signer-signer and csr-signer from the `openshift-kube-controller-manager-operator` namespace

```sh
oc delete secrets/csr-signer-signer secrets/csr-signer -n openshift-kube-controller-manager-operator
```

Watch operators progress:

```sh
watch oc get clusteroperators
```

Fix monitoring certificate rotation

```sh
# Get the configMap
oc get configmap extension-apiserver-authentication -n kube-system -o yaml >extension-apiserver-authentication.yaml

# Add a space after any END CERTIFICATE line and save the file

# Reapply the configMap
oc apply -f extension-apiserver-authentication.yaml
```


After restart, check if nodes are ready with `oc get nodes`. If not ready, run:

```sh
oc get csr -oname | xargs oc adm certificate approve
```

And check the nodes again.


### F5 IRule for L7 VS:

Check note [[F5 Configuration for L7 Certificates]]

## NetworkPolicy

```bash
$ cat <<EOF >allow-same-namespace.yml
---
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: allow-same-namespace
spec:
  podSelector: {}
  ingress:
  - from:
    - podSelector: {}
EOF
$ oc create -n cakephp-example -f allow-same-namespace.yml

$ cat <<EOF >allow-openshift-ingress.yml
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-openshift-ingress
spec:
  podSelector: {}
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          network.openshift.io/policy-group: ingress
EOF
$ oc create -n cakephp-example -f allow-openshift-ingress.yml
```
