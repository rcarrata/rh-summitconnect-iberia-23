# Demo 2 - Connecting MultiClustering applications using Red Hat Interconnect

This demo locates the frontend and backend services in different namespaces, on different clusters.  Ordinarily, this means that they have no way to communicate unless they are exposed to the public internet.

Introducing Skupper into each namespace allows us to create a virtual application network that can connect services in different clusters. Any service exposed on the application network is represented as a local service in all of the linked namespaces.

The backend service is located in `ARO` cluster, but the frontend service in `ROSA` cluster can "see" it as if it were local.  When the frontend sends a request to the backend, Skupper forwards the request to the namespace where the backend is running and routes the response back to the frontend.

#### Contents

* [Overview](#overview)
* [Prerequisites](#prerequisites)
* [Step 1: Install the Skupper command-line tool](#step-1-install-the-skupper-command-line-tool)
* [Step 2: Configure separate console sessions](#step-2-configure-separate-console-sessions)
* [Step 3: Access your clusters](#step-3-access-your-clusters)
* [Step 4: Set up your namespaces](#step-4-set-up-your-namespaces)
* [Step 5: Install Skupper in your namespaces](#step-5-install-skupper-in-your-namespaces)
* [Step 6: Check the status of your namespaces](#step-6-check-the-status-of-your-namespaces)
* [Step 7: Link your namespaces](#step-7-link-your-namespaces)
* [Step 8: Deploy the frontend and backend services](#step-8-deploy-the-frontend-and-backend-services)
* [Step 9: Expose the backend service](#step-9-expose-the-backend-service)
* [Step 10: Expose the frontend service](#step-10-expose-the-frontend-service)
* [Step 11: Test the application](#step-11-test-the-application)
* [Accessing the web console](#accessing-the-web-console)
* [Cleaning up](#cleaning-up)
* [Summary](#summary)
* [About this example](#about-this-example)

## Overview

This example is a very simple multi-service HTTP application
deployed across Kubernetes clusters using Skupper.

It contains two services:

* A backend service that exposes an `/api/hello` endpoint.  It
  returns greetings of the form `Hi, <your-name>.  I am <my-name>
  (<pod-name>)`.

* A frontend service that sends greetings to the backend and
  fetches new greetings in response.

With Skupper, you can place the backend in one cluster and the
frontend in another and maintain connectivity between the two
services without exposing the backend to the public internet.

## Prerequisites

### Deploy ROSA Cluster

* Define the prerequisites for install the ROSA cluster

```sh
export VERSION=4.11.36 \
      ROSA_CLUSTER_NAME=poc-inter-1 \
      AWS_ACCOUNT_ID=`aws sts get-caller-identity --query Account --output text` \
      REGION=eu-west-1 \
      AWS_PAGER="" \
      CIDR="10.10.0.0/16"

```

* Create roles and cluster admin

```sh
rosa create account-roles --mode auto
rosa create cluster --cluster-name $CLUSTER_NAME --sts --mode auto --yes
```

I: To determine when your cluster is Ready, run 'rosa describe cluster -c $CLUSTER_NAME'.
I: To watch your cluster installation logs, run 'rosa logs install -c $CLUSTER_NAME --watch'.

```md
rosa create admin -c $CLUSTER_NAME
```

```
oc login https://api.poc-inter-1.xxx.com:6443 --username cluster-admin --password xxx
```

### Deploy ARO cluster

* Define the prerequisites for install the ARO cluster

```sh
AZR_RESOURCE_LOCATION=eastus
AZR_RESOURCE_GROUP=poc-inter-2-rg
AZR_CLUSTER=poc-inter-2
AZR_PULL_SECRET=~/Downloads/pull-secret.txt
```

* Create an Azure resource group

```sh
 az group create \
   --name $AZR_RESOURCE_GROUP \
   --location $AZR_RESOURCE_LOCATION
```

* Create virtual network

```sh
 az network vnet create \
   --address-prefixes 10.0.0.0/22 \
   --name "$AZR_CLUSTER-aro-vnet-$AZR_RESOURCE_LOCATION" \
   --resource-group $AZR_RESOURCE_GROUP
```

* Create control plane subnet

```sh
 az network vnet subnet create \
   --resource-group $AZR_RESOURCE_GROUP \
   --vnet-name "$AZR_CLUSTER-aro-vnet-$AZR_RESOURCE_LOCATION" \
   --name "$AZR_CLUSTER-aro-control-subnet-$AZR_RESOURCE_LOCATION" \
   --address-prefixes 10.0.0.0/23 \
   --service-endpoints Microsoft.ContainerRegistry
```

* Create machine subnet

```sh
az network vnet subnet create \
  --resource-group $AZR_RESOURCE_GROUP \
  --vnet-name "$AZR_CLUSTER-aro-vnet-$AZR_RESOURCE_LOCATION" \
  --name "$AZR_CLUSTER-aro-machine-subnet-$AZR_RESOURCE_LOCATION" \
  --address-prefixes 10.0.2.0/23 \
  --service-endpoints Microsoft.ContainerRegistry
```

* Disable network policies on the control plane subnet

```bash
az network vnet subnet update \
  --name "$AZR_CLUSTER-aro-control-subnet-$AZR_RESOURCE_LOCATION" \
  --resource-group $AZR_RESOURCE_GROUP \
  --vnet-name "$AZR_CLUSTER-aro-vnet-$AZR_RESOURCE_LOCATION" \
  --disable-private-link-service-network-policies true
```

* Create the ARO cluster

```sh
 az aro create \
   --resource-group $AZR_RESOURCE_GROUP \
   --name $AZR_CLUSTER \
   --vnet "$AZR_CLUSTER-aro-vnet-$AZR_RESOURCE_LOCATION" \
   --master-subnet "$AZR_CLUSTER-aro-control-subnet-$AZR_RESOURCE_LOCATION" \
   --worker-subnet "$AZR_CLUSTER-aro-machine-subnet-$AZR_RESOURCE_LOCATION" \
   --pull-secret @$AZR_PULL_SECRET
```

* Get ARO OpenShift API Url

```sh
ARO_URL=$(az aro show -g $AZR_RESOURCE_GROUP -n $AZR_CLUSTER --query apiserverProfile.url -o tsv)
```

* Login into the ARO cluster and set context

```sh
ARO_KUBEPASS=$(az aro list-credentials --name $AZR_CLUSTER --resource-group $AZR_RESOURCE_GROUP -o tsv --query kubeadminPassword)
```

* Login into the ARO cluster and set context

```sh
oc login --username kubeadmin --password $ARO_KUBEPASS --server=$ARO_URL
```

## Installing and Configuring Skupper CLI & Kubeconfigs

* Install the Skupper command-line tool

```bash
curl https://skupper.io/install.sh | sh
```

Skupper is designed for use with multiple namespaces, usually on
different clusters.  The `skupper` command uses your
[kubeconfig][kubeconfig] and current context to select the
namespace where it operates.

* Configure Kubeconfig for MultiClustering

```bash
rm -rf /var/tmp/interconnect-lab-kubeconfig
touch /var/tmp/interconnect-lab-kubeconfig
export KUBECONFIG=/var/tmp/interconnect-lab-kubeconfig

oc login https://api.poc-inter-1.xx.xxx.xxx.com:6443 --username cluster-admin --password xxx
kubectl config rename-context $(oc config current-context) $ROSA_CLUSTER_NAME
kubectl config use $ROSA_CLUSTER_NAME

oc login --username kubeadmin --password $ARO_KUBEPASS --server=$ARO_URL
kubectl config rename-context $(oc config current-context) $AZR_CLUSTER
kubectl config use $AZR_CLUSTER
```

## Install Skupper in your namespaces

The `skupper init` command installs the Skupper router and service
controller in the current namespace.  

Run the `skupper init` command in each cluster:

_**ROSA Cluster**_

```bash
kubectl config use $CLUSTER_NAME
echo "I am in $CLUSTER_NAME!"
kubectl create namespace rosa
kubectl config set-context --current --namespace rosa

skupper init --enable-console --enable-flow-collector
```

_**ARO Cluster**_

```bash
skupper init
```

## Check the status of your namespaces

* Use `skupper status` in each console to check that Skupper is installed.

_**ROSA Cluster**_

```bash
kubectl config use $CLUSTER_NAME
echo "I am in $CLUSTER_NAME!"
skupper status
```

_**ARO Cluster**_

```bash
kubectl config use $CLUSTER_NAME_2
echo "I am in $CLUSTER_NAME_2!"
skupper status
```

## Link your namespaces

Creating a link requires use of two `skupper` commands in
conjunction, `skupper token create` and `skupper link create`.

The `skupper token create` command generates a secret token that
signifies permission to create a link.  The token also carries the
link details.  Then, in a remote namespace, The `skupper link
create` command uses the token to create a link to the namespace
that generated it.

**Note:** The link token is truly a *secret*.  Anyone who has the
token can link to your namespace.  Make sure that only those you
trust have access to it.

First, use `skupper token create` in one namespace to generate the
token.  Then, use `skupper link create` in the other to create a
link.

_**ROSA Cluster**_

```bash
kubectl config use $CLUSTER_NAME
echo "I am in $CLUSTER_NAME!"
skupper token create /tmp/secret.token
```

_**ARO Cluster**_

```bash
kubectl config use $CLUSTER_NAME_2
echo "I am in $CLUSTER_NAME_2!"
skupper link create /tmp/secret.token
```

* In the same ARO cluster, check the skupper link status and see if the Link is with the connected status:

```bash
skupper link status
```

## Deploy the frontend and backend services

Use `kubectl create deployment` to deploy the frontend service in `ROSA` and the backend service in `ARO`.

_**ROSA Cluster**_

* Deploy the frontend in the ROSA cluster:

```
kubectl config use $CLUSTER_NAME
echo "I am in $CLUSTER_NAME!"
kubectl create --namespace rosa deployment frontend --image quay.io/rcarrata/skupper-summit-frontend:v4
```

_**ARO Cluster**_

* Deploy the backend in the ROSA cluster:

```
kubectl config use $CLUSTER_NAME_2
echo "I am in $CLUSTER_NAME_2!"
kubectl create --namespace aro deployment backend --image quay.io/rcarrata/skupper-summit-backend:v4 --replicas 3
```

## Expose the backend service

We have established connectivity between the two namespaces and made the backend in `ARO` available to the frontend in `ROSA`.

Before we can test the application, we need external access to the frontend.

_**ROSA Cluster**_

```
echo "I am in $CLUSTER_NAME_2!"
skupper expose deployment/backend --port 8080
```

_**ARO Cluster**_

```
kubectl config use $CLUSTER_NAME
echo "I am in $CLUSTER_NAME!"
kubectl expose deployment/frontend --port 8080
oc expose svc/frontend
```

* TODO: convert the app into HTTPS (edge)

## Test the application

Now we're ready to try it out.  Use `kubectl get route frontend` to look up the external IP of the frontend route.  Then use `curl` or a similar tool to request the `/api/health` endpoint at
that address.

_**ROSA Cluster**_

```bash
kubectl config use $CLUSTER_NAME
echo "I am in $CLUSTER_NAME!"
FRONTEND_URL=$(kubectl get route -n west frontend -o jsonpath='{.spec.host}')
curl http://$FRONTEND_URL/api/health
```

If everything is in order, you can now access the web interface by navigating to `http://$FRONTEND_URL` in your browser.

## Accessing the web console

Skupper includes a web console you can use to view the application network.  To access it, use `skupper status` to look up the URL of the web console.  Then use `kubectl get secret/skupper-console-users` to look up the console admin password.

_**ROSA Cluster**_

```bash
skupper status
kubectl get route -n west skupper -o jsonpath='{.spec.host}'
kubectl get secret/skupper-console-users -o jsonpath={.data.admin} | base64 -d
```

Navigate to the Skupper Console in your browser.  When prompted, log in as user `admin` and enter the password.