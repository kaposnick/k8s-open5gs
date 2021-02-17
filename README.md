# Cloud native Open5Gs

This repository is about how to deploy a cloud native Open5Gs core using kubernetes and minikube.

Main repository of my master thesis:

1. Title: <b>Performance evaluation of E2E service orchestration</b> 
2. Course: <b>Master in NFV/SDN for 5G Networks 2020/21</b> 
3. University: <b>Universidad Carlos III de Madrid (UC3M)</b>

## Setup your environment
Tools that you will need in order to build and run the cloud native Open5Gs:

##### 1. minikube
```shell
mkdir minikube
git clone https://github.com/kubernetes/minikube.git minikube
cd minikube
make
sudo install ./out/minikube /usr/local/bin
```
##### 2. kubectl
```shell 
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo install ./kubectl /usr/local/bin
```

##### 3. helm
Follow the instructions here: https://helm.sh/docs/intro/install/

## Produce the image
```shell
mkdir k8s-open5gs
git clone https://github.com/kaposnick/k8s-open5gs.git k8s-open5gs
cd k8s-open5gs
```

##### 1. open5gs-custom image
This image will be run by the Open5Gs functions
```shell 
docker build -t open5gs-custom .
```

##### 2. open5gs-webui image
This image will be run by the webui
```shell
cd webui
docker build -t open5gs-webui .
```

## Create the Kubernetes cluster and push the images
Run a local registry
```shell
docker run -d -p 5000:5000 --restart=always --name registry registry:2
```

Add the entry ```127.0.0.1 docker.local``` in the ```/etc/hosts```. 

Push the produced images to the local docker registry
```shell
docker push open5gs-custom docker.local:5000/open5gs-custom
docker push open5gs-webui docker.local:5000/open5gs-webui
``` 

Create the minikube kubernetes cluster using the default (docker) driver
```shell
minikube -p open5gs start
```

Add the images into the kubernetes cluster
```shell
minikube -p open5gs ssh
sudo apt update
sudo apt install vim
sudo systemctl edit docker.service
```
Fill in the following and save
```shell
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H tcp://0.0.0.0:2376 -H unix:///var/run/docker.sock --default-ulimit=nofile=1048576:1048576 --tlsverify --tlscacert /etc/docker/ca.pem --tlscert /etc/docker/server.pem --tlskey /etc/docker/server-key.pem --label provider=virtualbox --insecure-registry 10.96.0.0/12 --insecure-registry 192.168.49.1:5000
```

```shell
sudo systemctl daemon-reload
sudo systemctl restart docker.service
docker pull 192.168.49.1:5000/open5gs-custom 
docker pull 192.168.49.1:5000/open5gs-webui
docker tag 192.168.49.1:5000/open5gs-custom open5gs-custom
docker tag 192.168.49.1:5000/open5gs-webui open5gs-webui
```

# How to deploy the Open5Gs services
```shell
cd k8s-open5gs
helm install open5gs --create-namespace --namespace=open5gs ./k8s-4g-core/
```

In order to decomission it:
```shell
helm uninstall open5gs --namespace=open5gs
```

This by default will deploy all the services and exports the S1-U, S1-AP interfaces with a LoadBalancer IP on address ```1.2.3.4```. These values can be modified in ```./k8s-4g-core/values.yaml```.

In order to be able to access the address ```1.2.3.4``` the following configuration should be further applied:
```shell
minikube -p open5gs ssh
sudo ip addr add 1.2.3.4/32 dev eth0
exit
```
Now, we want to make this address routable from outside the kubernetes cluster.
When the kubernetes cluster is deployed a docker user defined bridge is created with name **open5gs**.

<pre><code>
$ docker network ls
NETWORK ID     NAME      DRIVER    SCOPE
e27df7e8b91e   bridge    bridge    local
91af76f3575a   host      host      local
dd19332f3b75   none      null      local
<b>532aa5a93026</b>   open5gs   bridge    local
</code>
</pre>

We can verify that this bridge exists issuing:
<pre><code>
$ ip link show type bridge
4: docker0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DEFAULT group default 
    link/ether 02:42:68:34:27:5f brd ff:ff:ff:ff:ff:ff
<b>10: br-532aa5a93026 </b>: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DEFAULT group default 
    link/ether 02:42:cc:2a:8c:8f brd ff:ff:ff:ff:ff:ff
</code></pre>

The last step we have to do is to add a static route to 1.2.3.4.
```shell
sudo ip route add 1.2.3.4/32 dev br-532aa5a93026
```

Now the address is pingable from our host machine
```shell
$ ping 1.2.3.4 -c 1
PING 1.2.3.4 (1.2.3.4) 56(84) bytes of data.
64 bytes from 1.2.3.4: icmp_seq=1 ttl=64 time=0.134 ms

--- 1.2.3.4 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.134/0.134/0.134/0.000 ms
```

## How to run the test scenarios
In order to run the test scenarios you have to have installed the srsENB, srsUE from srsLTE package.
Before we run each test we have to manually add some subscribers inside the hss-database

```shell
kubectl exec -it mongo-0 -- /bin/bash
bash /open5gs/config-map/reg_subscriber.sh
exit
git checkout master-thesis-scenarios
```

#### Scenario 1: [2 eNBs/4 UEs]
<pre><code>
cd thesis-scenarios/scenario_1
sudo ip netns add ue1
sudo ip netns add ue2
sudo ip netns add ue3
sudo ip netns add ue4
sudo srsenb --enb_files.rr_config rr.conf --enb_files.sib_config ../common/sib.conf --enb_files.drb_config ../common/drb.conf enb.conf
sudo srsenb --enb_files.rr_config rr.conf --enb_files.sib_config ../common/sib.conf --enb_files.drb_config ../common/drb.conf enb2.conf
sudo srsue ue.conf --gw.netns=ue1
sudo srsue ue2.conf --gw.netns=ue2
sudo srsue ue3.conf --gw.netns=ue3
sudo srsue ue4.conf --gw.netns=ue4
</code></pre>

#### Scenario 2: [1 eNB/ 1UE] Inter-eNB S1- Handover  
<pre><code>
cd thesis-scenarios/scenario_2
sudo ip netns add ue1
sudo ip netns add ue2
sudo srsenb --enb_files.rr_config rr1.conf --enb_files.sib_config ../common/sib.conf --enb_files.drb_config ../common/drb.conf enb.conf
sudo srsenb --enb_files.rr_config rr2.conf --enb_files.sib_config ../common/sib.conf --enb_files.drb_config ../common/drb.conf enb2.conf
sudo srsue ue.conf --gw.netns=ue1
python3 s1_handover.py 5
</code></pre>

## Copyright and license
MIT License

Copyright (c) 2021 Nikolaos Apostolakis

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.