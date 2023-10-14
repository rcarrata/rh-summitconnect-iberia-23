source ../utils/demo-magic.sh

pei "# Deploying Demo 1 - Cloud Services ACM Submariner"
pe "export KUBECONFIG=/var/tmp/acm-lab-kubeconfig"
pe "export ROSA_CLUSTER_NAME='rosa-summit-1'" 
pe "export ARO_CLUSTER='aro-summit'"
pei ""

pei "# Deploy GuestBook FrontEnd"
pe ""
pe "kubectl config use hub"
pe "oc apply -k ../../apps/guestbook-app/acm-resources"
pei ""

pei "# Deploy the Redis Master App in ROSA Cluster"
pe "oc apply -k ../../apps/redis-master-app/acm-resources"
pei ""

pei "# Adjust the SCCs in ROSA"
pe "kubectl config use $ROSA_CLUSTER_NAME"
pe "oc get dns cluster -o yaml"
pe "oc adm policy add-scc-to-user anyuid -z default -n guestbook"
pe "oc delete pod --all -n guestbook"
pei ""

pei "# Deploy the Redis Slave App in ARO Cluster"
pe "kubectl config use hub"
pe "oc apply -k ../../apps/redis-slave-app/acm-resources"
pei ""

pei "# Adjust the SCCs in ARO"
pe "kubectl config use $ARO_CLUSTER"
pe "oc get dns cluster -o yaml"
pe "oc adm policy add-scc-to-user anyuid -z default -n guestbook"
pe "oc delete pod --all -n guestbook"
pei ""

pei "# Go to Redis-Slave in ARO"
p 'for key in "$(redis-cli -p 6379 keys \*)"; do echo "Key : '$key'"; redis-cli -p 6379 GET $key; done'
