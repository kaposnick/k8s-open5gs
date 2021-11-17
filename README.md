# Cloud native Open5Gs

<img align="right" src="carlos_iii.png">

1. Title: <b>Performance evaluation of E2E service orchestration</b> 
2. Course: <b>Master in NFV/SDN for 5G Networks 2020/21</b> 
3. University: <b>Universidad Carlos III de Madrid (UC3M)</b>

## Create the Kubernetes Cluster
Create a K8S cluster of 3 nodes (1 Master + 2 Worker Nodes) using `kubeadm` utility. <br />
I used Ubuntu 20.04 as the base image of the VMs.
Annotate the 2 Worker Nodes with `mobile-core: cp` for the node containing Control Plane CNFs and `mobile-core: up` for the node contanining User Plane CNFs. <br/>
The nodes should be interconnected while the 2 Worker Nodes should be externally accessible for exporting the S1-AP, S1-MME interface. <br />
Used `Flannel` as the Container Networking Interface (CNI).


## Deploy the Open5Gs application
### 1. Modify the k8s-4g-core/values.yaml
The administrator should identify the externally accessible IP addresses exported by the 2 worker nodes and replace the 
* `mmeExternalAddress`, `webUiExternalAddress` values with that of the C-Plane node.
* `sgwuExternalAddress` value with that of the U-Plane node.

### 2. Create the `open5gs` namespace
```shell
cd k8s-4g-core
kubectl create namespace open5gs
```

### 3. Deploy the application within the `open5gs` namespace
```shell
helm install open5gs -n open5gs .
```

### 4. Retrieve the status
```shell
$ kubectl get pods -n open5gs -o wide
NAME                             READY   STATUS    RESTARTS   AGE    IP             NODE       NOMINATED NODE   READINESS GATES
mongo-0                          2/2     Running   0          7d3h   10.244.10.59   worker-1   <none>           <none>
open5gs-hss-deployment-0         1/1     Running   3          7d3h   10.244.10.55   worker-1   <none>           <none>
open5gs-mme-deployment-0         1/1     Running   1          7d3h   10.244.10.58   worker-1   <none>           <none>
open5gs-pcrf-deployment-0        1/1     Running   3          7d3h   10.244.10.54   worker-1   <none>           <none>
open5gs-pgwc-deployment-0        1/1     Running   0          7d3h   10.244.10.60   worker-1   <none>           <none>
open5gs-pgwu-deployment-0        1/1     Running   0          7d3h   10.244.9.210   worker-2   <none>           <none>
open5gs-sgwc-deployment-0        1/1     Running   0          7d3h   10.244.10.56   worker-1   <none>           <none>
open5gs-sgwu-deployment-0        1/1     Running   0          7d3h   10.244.9.209   worker-2   <none>           <none>
open5gs-webui-7b8d78bbdb-slc2l   1/1     Running   2          7d3h   10.244.10.57   worker-1   <none>           <none>
```

The following steps are optional in case we want to have performance metrics collection from both the EPC and the RAN, using Prometheus.

## Deploy the Prometheus application (optional)
Deploy the Prometheus stack within the kubernetes cluster. This will install the `ServiceMonitor` K8S resource that will search for pods with label `app: srsenb` within the `open5gs` namespace and set them as Prometheus targets.

```shell
cd k8s-open5gs
helm install -n monitoring prometheus -f ../prometheus-values.yaml prometheus-community/kube-prometheus-stack
```

## Deploy the srsENB proxy pods (optional)
The srsENB process must listen on an cluster-accessible IP address and port.
Then for every srsENB process that we want to monitor, deploy a helm chart issuing:

```shell
cd srsenb-chart
helm install <srsenbname> -n open5gs --set enb.ip=<enb-ip> --set enb.port=<enb.port> .
```

When the Prometheus's ServiceDiscovery discovers the proxy pods, the srsENB will start getting polled and the metrics will starting getting received.