source ../utils/demo-magic.sh

pei "# Deploying Demo 1 - Cloud Services ACM Submariner"
pe "export KUBECONFIG=/var/tmp/acm-lab-kubeconfig"
pe "export ROSA_CLUSTER_NAME='rosa-rcarrata'" 
pe "export ARO_CLUSTER='aro-rcarrata'"
pei ""

pei "# Clone Apps Demo Repository"
pe "git clone https://github.com/rh-mobb/acm-demo-app /tmp/acm-demo-app && cd /tmp/acm-demo-app"
pei ""

pei "# Deploy GuestBook FrontEnd"
pe "kubectl config use hub && oc apply -k guestbook-app/acm-resources"
pei ""

pei "# Deploy the Redis Master App in ROSA Cluster"
pe "oc apply -k redis-master-app/acm-resources"
pei ""

pei "# Deploy the Redis Master App in ROSA Cluster"
pe "kubectl config use $ROSA_CLUSTER_NAME"
pe "oc adm policy add-scc-to-user anyuid -z default -n guestbook"
pe "oc delete pod --all -n guestbook"
pei ""

pei "# Deploy the Redis Slave App in ROSA Cluster 2"
pe "kubectl config use hub"
pe "oc apply -k redis-slave-app/acm-resources"
pei ""


pei "# Apply relaxed SCC only for this PoC"
pe "kubectl config use $ROSA_CLUSTER_NAME_2"
pe "oc adm policy add-scc-to-user anyuid -z default -n guestbook"
pe "oc delete pod --all -n guestbook"
pei ""