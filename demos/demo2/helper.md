# Set up Context

```sh
export ROSA_CLUSTER_NAME=rosa-summit
export ARO_CLUSTER=aro-summit

rm -rf /var/tmp/acm-lab-kubeconfig
touch /var/tmp/acm-lab-kubeconfig
export KUBECONFIG=/var/tmp/acm-lab-kubeconfig


oc login https://api.rosa-summit-1.jb0i.p1.openshiftapps.com:6443 --username cluster-admin --password LFTur-y9d5K-Mai6w-wfU58
kubectl config rename-context $(oc config current-context) $ROSA_CLUSTER_NAME
kubectl config use $ROSA_CLUSTER_NAME

oc login https://api.naswexgs.westeurope.aroapp.io:6443/ --username kubeadmin --password FXCMJ-tXDWb-9PYJJ-8KMbg
kubectl config rename-context $(oc config current-context) $ARO_CLUSTER
kubectl config use $ARO_CLUSTER
```

# Set up ROSA RH Interconnect + deploy frontend
```sh
kubectl config use $ROSA_CLUSTER_NAME
kubectl create namespace rosa-interconnect

cat << EOF | kubectl apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: skupper-operator
  namespace: openshift-operators
spec:
  channel: alpha
  installPlanApproval: Automatic
  name: skupper-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

SUB=$(oc get subs -n openshift-operators skupper-operator -o yaml -o template --template '{{.status.currentCSV}}')

oc get csv $SUB -n openshift-operators -o template --template '{{.status.phase}}'

kubectl create --namespace rosa-interconnect deployment frontend --image quay.io/rcarrata/skupper-summit-frontend:v4

kubectl get deploy frontend --namespace rosa-interconnect

kubectl expose deployment/frontend --port 8080 --namespace rosa-interconnect
oc create route edge --service=frontend --namespace rosa-interconnect
```

# Set up ARO RH Interconnect
```sh
kubectl config use $ARO_CLUSTER
kubectl create namespace aro-interconnect

cat << EOF | kubectl apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: skupper-operator
  namespace: openshift-operators
spec:
  channel: alpha
  installPlanApproval: Automatic
  name: skupper-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

SUB=$(oc get subs -n openshift-operators skupper-operator -o yaml -o template --template '{{.status.currentCSV}}')


oc get csv $SUB -n openshift-operators -o template --template '{{.status.phase}}'

kubectl create --namespace aro-interconnect deployment backend --image quay.io/rcarrata/skupper-summit-backend:v4 --replicas 3

kubectl get deploy backend --namespace aro-interconnect
```

# Clean up

```sh
kubectl config use $ROSA_CLUSTER_NAME
oc delete project rosa-interconnect
oc delete project rosa-interconnect-backup

kubectl config use $ARO_CLUSTER
oc delete project aro-interconnect
oc delete project aro-interconnect-backup
```


# Backup 

```sh
kubectl config use $ROSA_CLUSTER_NAME
kubectl create namespace rosa-interconnect-backup

kubectl create --namespace rosa-interconnect-backup deployment frontend --image quay.io/rcarrata/skupper-summit-frontend:v4

kubectl get deploy frontend --namespace rosa-interconnect-backup

kubectl expose deployment/frontend --port 8080 --namespace rosa-interconnect-backup
oc create route edge --service=frontend --namespace rosa-interconnect-backup

kubectl config use $ARO_CLUSTER
kubectl create namespace aro-interconnect-backup

kubectl create --namespace aro-interconnect-backup deployment backend --image quay.io/rcarrata/skupper-summit-backend:v4 --replicas 3

kubectl get deploy backend --namespace aro-interconnect-backup

kubectl config use $ROSA_CLUSTER_NAME

cat << EOF | kubectl apply -n rosa-interconnect-backup -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: skupper-site
data:
  router-mode: interior
  console-user: 'admin'
  console-password: 'admin'
  console: 'true'
  flow-collector: 'true'
EOF

kubectl config use $ARO_CLUSTER

cat << EOF | kubectl apply -n aro-interconnect-backup -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: skupper-site
EOF

kubectl config use $ROSA_CLUSTER_NAME
skupper token create /tmp/secretbackup.token -n rosa-interconnect-backup

kubectl config use $ARO_CLUSTER
skupper link create /tmp/secretbackup.token -n aro-interconnect-backup
skupper link status -n aro-interconnect-backup --wait 60

skupper expose deployment/backend -n aro-interconnect-backup --port 8080
`````` 
 