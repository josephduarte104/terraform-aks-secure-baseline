# provider "kubernetes" {
#   load_config_file        = false
#   host                    = module.azure_aks.kube_config.0.host
#   username                = module.azure_aks.kube_config.0.username
#   password                = module.azure_aks.kube_config.0.password
#   client_certificate      = base64decode(module.azure_aks.kube_config.0.client_certificate)
#   client_key              = base64decode(module.azure_aks.kube_config.0.client_key)
#   cluster_ca_certificate  = base64decode(module.azure_aks.kube_config.0.cluster_ca_certificate)
# }

# resource "kubernetes_namespace" "example" {
#   metadata {
#     annotations = {
#       name = "example-annotation"
#     }

#     labels = {
#       mylabel = "label-value"
#     }

#     name = "terraform-example-namespace"
#   }
# }