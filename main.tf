locals {
  context = var.context
}

#
# Walrus Ingress
#

resource "kubernetes_ingress" "walrus_ingress" {
  metadata {
    name      = "walrus"
    namespace = var.namespace_name
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
            service_name = "walrus"
            service_port = 80
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

resource "kubernetes_manifest" "app_manifest" {
  manifest = yamldecode(file("value.yaml"))
}