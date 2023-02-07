<img src="carlos_iii.png">

<b>Design and Validation of an Open Source Cloud Native Mobile Network</b> 

The repository contains the code and data of the paper "Design and Validation of an Open Source Cloud Native Mobile Network" by N. Apostolakis, M. Gramaglia, P. Serrano. Please cite the paper if you plan to use it in your publication.

```BibTex
@ARTICLE{9877928,
  author={Apostolakis, Nikolaos and Gramaglia, Marco and Serrano, Pablo},
  journal={IEEE Communications Magazine}, 
  title={Design and Validation of an Open Source Cloud Native Mobile Network}, 
  year={2022},
  volume={60},
  number={11},
  pages={66-72},
  doi={10.1109/MCOM.003.2200195}}
```

## Create the VM Network topology
* Latest Ubuntu 20.04 LTS version as VMs' base image
* Using `KVM`, `virsh` and `virt-manager`, create 3 VM domains; 1 for Master Node, 2 Worker Nodes. Give each one at least of 10G of disk space (this is important as while deploying the open5Gs pods, the node may suffer from disk pressure)
* Manage the VMs either using `virsh console`, or install an OpenSSH server
* Create the internal topology for control-plane and inter-pod communication. Also, create external interfaces to the worker nodes in order to provide S1-MME/N2 and S1-U/N3 connectivity towards the RAN

## Create the Kubernetes Cluster
* Install `Docker`, `kubelet`, `kubeadm` in all the nodes
* Additionally, install `kubectl` in the master node
* Issue `kubeadm init` in the master node to create the Kubernetes Cluster. Use the argument `--apiserver-advertise-address <interface-ip>` to specify the IP address to be advertised to the worker nodes for the control plane communication. 
* Issue `kubeadm join` in the worker nodes using the credentials provided by the master node.* Annotate the 2 Worker Nodes with `mobile-core: cp` for the node containing Control Plane CNFs and `mobile-core: up` for the node contanining User Plane CNFs. <br/>
* Setup the CNI: Flannel is going to be used as the container networking interface. Modify the `--iface` argument within the `kube-flannel.yaml` file in order to match the interface interconnecting the master node with the worker nodes and issue `kubectl apply -f kube-flannel.yml` in order to install the CNI in all of the worker nodes
* Make sure that the `dockerd` service in the worker nodes use the CNI for setting up the communication between the containers


## Deploy the Open5Gs application
### 1. Modify the k8s-5g-core/values.yaml
The administrator should identify the externally accessible IP addresses exported by the 2 worker nodes and replace the 
* `mmeExternalAddress`, `webUiExternalAddress` values with that of the C-Plane node.
* `sgwuExternalAddress` value with that of the U-Plane node.

### 2. Create the `open5gs` namespace
```shell
cd k8s-5g-core
kubectl create namespace open5gs
```

### 3. Deploy the application within the `open5gs` namespace
```shell
helm install open5gs -n open5gs .
```

### 4. Verify the state
```shell
$ kubectl get pods -n open5gs -o wide
NAME                              READY   STATUS    RESTARTS        AGE
mongo-0                           1/1     Running   0               3h40m
open5gs1-amf-deployment-0         1/1     Running   0               3h40m
open5gs1-ausf-deployment-0        1/1     Running   0               3h40m
open5gs1-bsf-deployment-0         1/1     Running   0               3h40m
open5gs1-nrf-deployment-0         1/1     Running   0               3h40m
open5gs1-nssf-deployment-0        1/1     Running   0               3h40m
open5gs1-pcf-deployment-0         1/1     Running   0               3h40m
open5gs1-pgwc-deployment-0        1/1     Running   0               3h40m
open5gs1-pgwu-deployment-0        1/1     Running   0               3h40m
open5gs1-udm-deployment-0         1/1     Running   0               3h40m
open5gs1-udr-deployment-0         1/1     Running   0               3h40m
open5gs1-webui-844ffb56d6-4spp2   1/1     Running   0               3h40m
```

The following steps are optional in case we want to have performance metrics collection from both the EPC/5GC and the RAN, using Prometheus.

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
helm install <srsenbname> -n open5gs --set enb.ip=<enb-ip> --set enb.port=<enb-port> .
```

When the Prometheus's ServiceDiscovery discovers the proxy pods, the srsENB will start getting polled and the metrics will starting getting received.