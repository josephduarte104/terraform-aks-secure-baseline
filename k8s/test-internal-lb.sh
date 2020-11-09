#!/bin/bash

BLUE="false"
GREEN="false"

# These are the blue nodes that can be scheduled
kubectl get nodes -l nodepoolcolor=blue --no-headers | grep -v SchedulingDisabled 
if [ $? == 0 ]; then
  BLUE="true"
fi

# These are the green nodes that can be scheduled
kubectl get nodes -l nodepoolcolor=green --no-headers | grep -v SchedulingDisabled 
if [ $? == 0 ]; then
  GREEN="true"
fi

echo "GREEN POOL is $GREEN"
echo "BLUE POOL is $BLUE"

# Create a namespace for your ingress resources
kubectl create namespace nginx

# Add the ingress-nginx repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

if [ $BLUE = "true" ]; then
	# Use Helm to deploy an NGINX ingress controller
	helm install ingress-blue ingress-nginx/ingress-nginx -f - \
	    --namespace nginx \
	    --set controller.replicaCount=2 \
	    --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
	    --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux \
	    --set controller.service.loadBalancerIP=192.168.4.4 \
            --set controller.nodeSelector.nodepoolcolor="blue" << EOF
controller:
  service:
    annotations:
      service.beta.kubernetes.io/azure-load-balancer-internal: "true"
      service.beta.kubernetes.io/azure-load-balancer-internal-subnet: "clusteringressservices"
EOF
fi

if [ $GREEN = "true" ]; then
	# Use Helm to deploy an NGINX ingress controller
	helm install ingress-green ingress-nginx/ingress-nginx -f - \
	    --namespace nginx \
	    --set controller.replicaCount=2 \
	    --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
	    --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux \
	    --set controller.service.loadBalancerIP=192.168.4.5 \
            --set controller.nodeSelector.nodepoolcolor="green" << EOF
controller:
  service:
    annotations:
      service.beta.kubernetes.io/azure-load-balancer-internal: "true"
      service.beta.kubernetes.io/azure-load-balancer-internal-subnet: "clusteringressservices"
EOF
fi

