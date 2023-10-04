source ../utils/demo-magic.sh

pei "# Demo 2 - Red Hat Interconnect"
pe "export KUBECONFIG=/var/tmp/interconnect-lab-kubeconfig"
pe "export ROSA_CLUSTER_NAME='rosa-summit'"
pe "export ARO_CLUSTER='aro-summit'"
pei ""

pei "# Test the application"
pe "kubectl config set-context $ROSA_CLUSTER_NAME --namespace=rosa-interconnect"
pe "FRONTEND_URL=$(kubectl get route frontend -o jsonpath='{.spec.host}')"
pe "curl https://$FRONTEND_URL/api/health"
pei ""

pei "# Creating Skupper Site in ROSA"
pe "cat << EOF | kubectl apply -f -
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
EOF"
PROMPT_TIMEOUT=10
wait
pei ""

pei "# Creating Skupper Site in ARO"
pe "kubectl config set-context $ARO_CLUSTER --namespace=aro-interconnect"
pe "cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: skupper-site
EOF"
PROMPT_TIMEOUT=10
wait
pei ""

pei "# Creating Skupper links in ROSA"
pe "kubectl config set-context $ROSA_CLUSTER_NAME --namespace=rosa-interconnect"
pe "skupper token create /tmp/secret.token"

pei "# Creating Skupper links in ARO"
pe "kubectl config set-context $ARO_CLUSTER --namespace=aro-interconnect"
pe "skupper link create /tmp/secret.token"
pe "skupper link status --wait 60"

pei "# Expose the backend service in ARO"
pe "skupper expose deployment/backend --port 8080"
pei ""

PROMPT_TIMEOUT=10
wait
pei ""

pei "# Test the application"
pe "kubectl config set-context $ROSA_CLUSTER_NAME --namespace=rosa-interconnect"
pe "FRONTEND_URL=$(kubectl get route frontend -o jsonpath='{.spec.host}')"
pe "curl https://$FRONTEND_URL/api/health"
pei ""