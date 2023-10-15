export KUBECONFIG=/var/tmp/acm-lab-kubeconfig
export ROSA_CLUSTER_NAME='rosa-summit-1'
export ARO_CLUSTER='aro-summit-1'

oc delete -k ../../apps/guestbook-app/acm-resources
oc delete -k ../../apps/redis-master-app/acm-resources
oc delete -k ../../apps/redis-slave-app/acm-resources
