# provider "kubernetes" {
#   load_config_file        = false
#   host                    = module.azure_aks.kube_config.0.host
#   #username                = module.azure_aks.kube_config.0.username
#   #password                = module.azure_aks.kube_config.0.password
#   client_certificate      = base64decode(module.azure_aks.kube_config.0.client_certificate)
#   client_key              = base64decode(module.azure_aks.kube_config.0.client_key)
#   cluster_ca_certificate  = base64decode(module.azure_aks.kube_config.0.cluster_ca_certificate)
# }

# provider "helm" {
#   kubernetes {
#     host                    = module.azure_aks.kube_config.0.host
#     #username                = module.azure_aks.kube_config.0.username
#     #password                = module.azure_aks.kube_config.0.password
#     client_certificate      = base64decode(module.azure_aks.kube_config.0.client_certificate)
#     client_key              = base64decode(module.azure_aks.kube_config.0.client_key)
#     cluster_ca_certificate  = base64decode(module.azure_aks.kube_config.0.cluster_ca_certificate)
#     load_config_file         = false
#   }
# }


# resource "kubernetes_namespace" "nginx" {
#   metadata {
#     annotations = {
#       name = "nginx"
#     }
#     name = "nginx"
#   }
# }

# resource "helm_release" "nginx" {
#   name       = "nginx-ingress"
#   repository = "https://kubernetes.github.io/ingress-nginx"
#   chart      = "ingress-nginx"
#   #namespace  = kubernetes_namespace.nginx.metadata[0].name
#   namespace  = "nginx"
#   depends_on  = ["kubernetes_namespace.nginx"]
#   set {
#     name    = "controller.replicaCount"
#     value   = 2
#   }

#   set_string {
#     name = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-internal"
#     value = "true"
#   }

#   set_string {
#     name = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-internal-subnet"
#     value = "clusteringressservices"
#   }
  
#   set {
#     name = "controller.service.loadBalancerIP"
#     value = module.appgateway.backend_address_pool[0]
#   }

# }