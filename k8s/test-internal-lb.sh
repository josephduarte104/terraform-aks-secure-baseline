#!/bin/bash -x

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
	IP=192.168.4.4
	# Use Helm to deploy an NGINX ingress controller
	helm install ingress-blue ingress-nginx/ingress-nginx -f - \
	    --namespace nginx \
	    --set controller.ingressClass=blue \
	    --set controller.replicaCount=2 \
	    --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
	    --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux \
	    --set controller.service.loadBalancerIP=$IP \
            --set controller.nodeSelector.nodepoolcolor=blue << EOF
controller:
  service:
    annotations:
      service.beta.kubernetes.io/azure-load-balancer-internal: "true"
      service.beta.kubernetes.io/azure-load-balancer-internal-subnet: "clusteringressservices"
EOF

    	sleep 5; while echo && kubectl get service -n nginx --no-headers | grep blue | grep -v -E "($IP|<none>)"; do sleep 5; done

cat <<EOF > nginx-blue.yaml 
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-blue-dep
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-blue
  template:
    metadata:
      labels:
        app: nginx-blue
    spec:
      nodeSelector:
        nodepoolcolor: blue
        nodepoolmode: user
      containers:
      - image: nginxdemos/hello
        name: nginx-blue
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "350m"
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-blue-svc
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: nginx-blue
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: nginx-blue-ing
  annotations:
    kubernetes.io/ingress.class: blue
    nginx.ingress.kubernetes.io/ingress.class: blue
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/rewrite-target: /$1
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  rules:
  - http:
       paths:
       - backend:
           serviceName: nginx-blue-svc
           servicePort: 80
         path: /(/|$)(.*)
       - backend:
           serviceName: nginx-blue-svc
           servicePort: 80
         path: /nginx(/|$)(.*)
EOF

fi

if [ $GREEN = "true" ]; then
	IP=192.168.4.5
	# Use Helm to deploy an NGINX ingress controller
	helm install ingress-green ingress-nginx/ingress-nginx -f - \
	    --namespace nginx \
	    --set controller.ingressClass=green \
	    --set controller.replicaCount=2 \
	    --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
	    --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux \
	    --set controller.service.loadBalancerIP=$IP \
            --set controller.nodeSelector.nodepoolcolor=green << EOF
controller:
  service:
    annotations:
      service.beta.kubernetes.io/azure-load-balancer-internal: "true"
      service.beta.kubernetes.io/azure-load-balancer-internal-subnet: "clusteringressservices"
EOF
    	sleep 5; while echo && kubectl get service -n nginx --no-headers | grep green | grep -v -E "($IP|<none>)"; do sleep 5; done

cat <<EOF > nginx-green.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-green-dep
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-green
  template:
    metadata:
      labels:
        app: nginx-green
    spec:
      nodeSelector:
        nodepoolcolor: green
        nodepoolmode: user
      containers:
      - image: nginxdemos/hello
        name: nginx-green
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "350m"
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-green-svc
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: nginx-green
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: nginx-green-ing
  annotations:
    kubernetes.io/ingress.class: green
    nginx.ingress.kubernetes.io/ingress.class: green
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/rewrite-target: /$1
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  rules:
  - http:
       paths:
       - backend:
           serviceName: nginx-green-svc
           servicePort: 80
         path: /(/|$)(.*)
       - backend:
           serviceName: nginx-green-svc
           servicePort: 80
         path: /nginx(/|$)(.*)
EOF
fi
