source ../utils/demo-magic.sh

pei "# Deploying Demo 2 - Red Hat Interconnect"
pe "export KUBECONFIG=/var/tmp/acm-lab-kubeconfig"
pe "export ROSA_CLUSTER_NAME='rosa-summit'" 
pe "export ARO_CLUSTER='aro-summit'"
pei ""

pei "# Check the Link status in ROSA"
pe "kubectl config use $ROSA_CLUSTER_NAME --namespace=rosa-interconnect"
pe "skupper link status"

pei "# Deploy the frontend in ROSA"
pe "kubectl config use $ROSA_CLUSTER_NAME --namespace=rosa-interconnect"
pe "kubectl create --namespace rosa-interconnect deployment frontend --image quay.io/rcarrata/skupper-summit-frontend:v4"
pei ""
pe "kubectl get deploy frontend"
pei ""

pei "# Deploy the frontend in ARO"
pe "kubectl config use $ARO_CLUSTER"
pe "kubectl create --namespace aro-interconnect deployment backend --image quay.io/rcarrata/skupper-summit-backend:v4 --replicas 3"
pei ""
pe "kubectl get deploy backend"
pei ""

pei "# Check the Link status in ARO"
pe "kubectl config use $ARO_CLUSTER --namespace=aro-interconnect"
pe "skupper link status"

pei "# Expose the backend service in ARO"
pe "skupper expose deployment/backend --port 8080"
pei ""

pei "# Expose the backend service in ROSA"
pe "kubectl config use $ROSA_CLUSTER_NAME --namespace=rosa-interconnect"
pe "kubectl expose deployment/frontend --port 8080"
pe "oc create route edge --service=frontend"
pei ""

pei "# Deploy the Redis Slave App in ROSA Cluster 2"
pe "kubectl config use hub"
pe "oc apply -k redis-slave-app/acm-resources"
pei ""

pei "# Test the application"
pe "kubectl config use $ROSA_CLUSTER_NAME --namespace=interconnect-rosa"
pe "FRONTEND_URL=$(kubectl get route frontend -o jsonpath='{.spec.host}')"
pe "echo "http://$FRONTEND_URL""
pe "curl http://$FRONTEND_URL/api/health"
pei ""

pei "# Accesing the web console"
pe "skupper status"
pe "kubectl get route skupper -o jsonpath='{.spec.host}'"
pe "kubectl -n rosa-interconnect get secret/skupper-console-users -o jsonpath={.data.admin} | base64 -d"
pei ""