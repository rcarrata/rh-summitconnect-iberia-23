source ../utils/demo-magic.sh

pei "# Demo 2 - Red Hat Interconnect"
pe "export KUBECONFIG=/var/tmp/acm-lab-kubeconfig"
pe "export ROSA_CLUSTER_NAME='rosa-summit-1'" 
pe "export ARO_CLUSTER='aro-summit-1'"
pei ""

pei "# Test the application"
pe "kubectl config use $ROSA_CLUSTER_NAME"
pe "FRONTEND_URL=$(kubectl get route frontend -o jsonpath='{.spec.host}' -n rosa-interconnect)"
pe "curl https://$FRONTEND_URL/api/health"
pei ""

pei "# Creating Skupper Site in ROSA"
pe "cat << EOF | kubectl apply -n rosa-interconnect -f -
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
pe "kubectl config use $ARO_CLUSTER"
pe "cat << EOF | kubectl apply -n aro-interconnect -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: skupper-site
EOF"
PROMPT_TIMEOUT=10
wait
pei ""

pei "# Creating Skupper links in ROSA"
pe "kubectl config use $ROSA_CLUSTER_NAME"
pe "skupper token create /tmp/secret.token -n rosa-interconnect"

pei "# Creating Skupper links in ARO"
pe "kubectl config use $ARO_CLUSTER"
pe "skupper link create /tmp/secret.token -n aro-interconnect"
pe "skupper link status -n aro-interconnect --wait 60"

pei "# Expose the backend service in ARO"
pe "skupper expose deployment/backend -n aro-interconnect --port 8080"
pei ""

PROMPT_TIMEOUT=10
wait
pei ""

pei "# Test the application"
pe "curl https://$FRONTEND_URL/api/health"
pei ""