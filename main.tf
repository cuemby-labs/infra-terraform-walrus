locals {
  context = var.context
}

#
# Walrus Ingress
#

resource "kubernetes_ingress_v1" "walrus_ingress" {
  metadata {
    name      = "walrus"
    namespace = "walrus-system"
    labels    = {
      "app.kubernetes.io/part-of"   = "walrus"
      "app.kubernetes.io/component" = "walrus"
    }
    annotations = {
      "cert-manager.io/issuer"                              = var.issuer
      "cert-manager.io/issuer-kind"                         = var.issuer_kind
      "cert-manager.io/issuer-group"                        = var.issuer_group
      "external-dns.alpha.kubernetes.io/cloudflare-proxied" = "true"
      "external-dns.alpha.kubernetes.io/hostname"           = "walrus.${var.domain_name}"
    }
  }
  spec {
    ingress_class_name = var.ingress_class_name
    tls {
      hosts       = ["walrus.${var.domain_name}"]
      secret_name = "walrus-${var.dash_domain_name}"
    }
    rule {
      host = "walrus.${var.domain_name}"
      http {
        path {
          backend {
            service {
              name = "walrus"
              port { 
                number = 80
              }
            }  
          }
          path     = "/"
        }
      }
    }
  }
}

#
# Walrus Manifest
#

data "kubectl_file_documents" "manifest_files" {
  content = file("${path.module}/values.yaml")
}

resource "kubectl_manifest" "apply_manifests" {
  for_each  = { for index, doc in data.kubectl_file_documents.manifest_files.documents : index => doc }

  yaml_body = each.value
}