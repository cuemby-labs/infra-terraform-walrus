locals {
  context = var.context
}

module "submodule" {
  source = "./modules/submodule"

  message = "Hello, submodule"
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
      "external-dns.alpha.kubernetes.io/hostname"           = var.host
    }
  }
  spec {
    ingress_class_name = var.ingress_class_name
    tls {
      hosts       = [var.host]
      secret_name = var.secret_name
    }
    rule {
      host = var.host
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
# Walrus secret
#

resource "kubernetes_secret" "walrus_secret" {
  metadata {
    name      = "walrus"
    namespace = var.namespace_name
    labels    = {
      "app.kubernetes.io/part-of"   = "walrus"
      "app.kubernetes.io/component" = "configuration"
    }
  }
  data = {
    local_environment_mode = "disabled"
    enable_tls             = "false"
    db_driver              = "postgres"
    db_user                = "root"
    db_password            = "Root123"
    db_name                = "walrus"
    minio_root_user        = "minio"
    minio_root_password    = "Minio123"
    minio_bucket           = "walrus"
  }
  type = "Opaque"
}

#
# Walrus Database
#

resource "kubernetes_config_map" "database_script" {
  metadata {
    name      = "database-script"
    namespace = var.namespace_name
  }
  data = {
    "init.sh" = <<-EOT
      #!/usr/bin/env bash

      set -o errexit
      set -o nounset
      set -o pipefail

      if [[ ! -d ${PGDATA} ]]; then
        mkdir -p ${PGDATA}
        chown 9999:9999 ${PGDATA}
      fi
    EOT

    "probe.sh" = <<-EOT
      #!/usr/bin/env bash

      set -o errexit
      set -o nounset
      set -o pipefail

      psql --no-password --username=${POSTGRES_USER} --dbname=${POSTGRES_DB} --command="SELECT 1"
    EOT
  }
}

resource "kubernetes_service" "database_service" {
  metadata {
    name      = "database"
    namespace = var.namespace_name
  }
  spec {
    selector = {
      "app.kubernetes.io/part-of"   = "walrus"
      "app.kubernetes.io/component" = "database"
    }
    port {
      name        = "conn"
      port        = 5432
      target_port = "conn"
    }
  }
}

resource "kubernetes_persistent_volume_claim" "database_pvc" {
  metadata {
    name      = "database"
    namespace = var.namespace_name
    labels    = {
      "app.kubernetes.io/part-of"   = "walrus"
      "app.kubernetes.io/component" = "database"
    }
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests  = {
        storage = "8Gi"
      }
    }
  }
}

resource "kubernetes_deployment" "database_deployment" {
  metadata {
    name      = "database"
    namespace = var.namespace_name
    labels    = {
      "app.kubernetes.io/part-of"   = "walrus"
      "app.kubernetes.io/component" = "database"
      "app.kubernetes.io/name"      = "postgres"
    }
  }
  spec {
    replicas = 1
    strategy {
      type = "Recreate"
    }
    selector {
      match_labels = {
        "app.kubernetes.io/part-of"   = "walrus"
        "app.kubernetes.io/component" = "database"
        "app.kubernetes.io/name"      = "postgres"
      }
    }
    template {
      metadata {
        labels = {
          "app.kubernetes.io/part-of"   = "walrus"
          "app.kubernetes.io/component" = "database"
          "app.kubernetes.io/name"      = "postgres"
        }
      }
      spec {
        automount_service_account_token = false
        restart_policy                  = "Always"
        init_container {
          name              = "init"
          image             = "postgres:16.1"
          image_pull_policy = "IfNotPresent"
          command           = ["/script/init.sh"]
          env {
            name  = "PGDATA"
            value = "/var/lib/postgresql/data/pgdata"
          }
          volume_mount {
            name       = "script"
            mount_path = "/script"
          }
          volume_mount {
            name       = "data"
            mount_path = "/var/lib/postgresql/data"
          }
        }
        container {
          name              = "postgres"
          image             = "postgres:16.1"
          image_pull_policy = "IfNotPresent"
          resources {
            limits   = {
              cpu    = "4"
              memory = "8Gi"
            }
            requests = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
          security_context {
            run_as_user = 9999
          }

          port {
            name           = "conn"
            container_port = 5432
          }
          env {
            name = "POSTGRES_USER"
            value_from {
              secret_key_ref {
                name = "walrus"
                key  = "db_user"
              }
            }
          }
          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = "walrus"
                key  = "db_password"
              }
            }
          }
          env {
            name = "POSTGRES_DB"
            value_from {
              secret_key_ref {
                name = "walrus"
                key  = "db_name"
              }
            }
          }
          env {
            name  = "PGDATA"
            value = "/var/lib/postgresql/data/pgdata"
          }
          startup_probe {
            failure_threshold = 10
            period_seconds    = 5
            exec {
              command = ["/script/probe.sh"]
            }
          }
          readiness_probe {
            failure_threshold = 3
            timeout_seconds   = 5
            period_seconds    = 5
            exec {
              command = ["/script/probe.sh"]
            }
          }
          liveness_probe {
            failure_threshold = 3
            timeout_seconds   = 5
            period_seconds    = 10
            exec {
              command = ["/script/probe.sh"]
            }
          }
          volume_mount {
            name      = "script"
            mount_path = "/script"
          }
          volume_mount {
            name      = "data"
            mount_path = "/var/lib/postgresql/data"
          }
        }
        volume {
          name = "script"
          config_map {
            name = "database-script"
            default_mode = 0555
          }
        }
        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = "database"
          }
        }
      }
    }
  }
}

#
# Walrus Minio Database
#

resource "kubernetes_persistent_volume_claim" "minio_pvc" {
  metadata {
    name      = "minio"
    namespace = var.namespace_name
    labels    = {
      "app.kubernetes.io/part-of"   = "walrus"
      "app.kubernetes.io/component" = "minio"
    }
  }
  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = "8Gi"
      }
    }
  }
}

resource "kubernetes_service" "minio_service" {
  metadata {
    name      = "minio"
    namespace = var.namespace_name
  }
  spec {
    selector = {
      "app.kubernetes.io/part-of"   = "walrus"
      "app.kubernetes.io/component" = "minio"
    }
    port {
      name        = "minio"
      port        = 9000
      target_port = "minio"
    }
  }
}

resource "kubernetes_deployment" "minio_deployment" {
  metadata {
    name      = "minio"
    namespace = var.namespace_name
    labels    = {
      "app.kubernetes.io/part-of"   = "walrus"
      "app.kubernetes.io/component" = "minio"
      "app.kubernetes.io/name"      = "minio"
    }
  }
  spec {
    selector {
      match_labels = {
        "app.kubernetes.io/part-of"   = "walrus"
        "app.kubernetes.io/component" = "minio"
        "app.kubernetes.io/name"      = "minio"
      }
    }
    strategy {
      type = "Recreate"
    }
    replicas = 1
    template {
      metadata {
        labels = {
          "app.kubernetes.io/part-of"   = "walrus"
          "app.kubernetes.io/component" = "minio"
          "app.kubernetes.io/name"      = "minio"
        }
      }
      spec {
        volume {
          name = "storage"
          persistent_volume_claim {
            claim_name = "minio"
          }
        }
        container {
          name             = "minio"
          image            = "minio/minio:RELEASE.2024-02-26T09-33-48Z"
          args             = ["server", "/storage"]
          resources {
            limits   = {
              cpu    = "1"
              memory = "1Gi"
            }
            requests = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
          port {
            name           = "minio"
            container_port = 9000
          }
          env {
            name = "MINIO_ROOT_USER"
            value_from {
              secret_key_ref {
                name = "walrus"
                key  = "minio_root_user"
              }
            }
          }
          env {
            name = "MINIO_ROOT_PASSWORD"
            value_from {
              secret_key_ref {
                name = "walrus"
                key  = "minio_root_password"
              }
            }
          }
          volume_mount {
            name      = "storage"
            mount_path = "/storage"
          }
        }
      }
    }
  }
}

#
# Identity Access Manager
#

resource "kubernetes_config_map" "identity_access_manager_script" {
  metadata {
    name      = "identity-access-manager-script"
    namespace = var.namespace_name
  }

  data = {
    "init.sh" = <<-EOT
      #!/usr/bin/env bash

      set -o errexit
      set -o nounset
      set -o pipefail

      # validate database
      set +o errexit
      while true; do
        if psql --command="SELECT 1" "${DB_SOURCE}" >/dev/null 2>&1; then
          break
        fi
        echo "waiting db to be ready ..."
        sleep 2s
      done
      set -o errexit

      # mutate app configuration
      cp -f /conf/app.conf app.conf
      sed -i '/^tableNamePrefix =.*/d' app.conf
      echo "tableNamePrefix = casdoor_" >>app.conf
      sed -i '/^driverName =.*/d' app.conf
      echo "driverName = \"${DB_DRIVER}\"" >>app.conf
      sed -i '/^dataSourceName =.*/d' app.conf
      echo "dataSourceName = \"${DB_SOURCE}\"" >>app.conf
      sed -i '/^sessionConfig =.*/d' app.conf
      echo 'sessionConfig = {"enableSetCookie":true,"cookieName":"casdoor_session_id","cookieLifeTime":3600,"providerConfig":"/var/run/casdoor","gclifetime":3600,"domain":"","secure":false,"disableHTTPOnly":false}' >>app.conf
      sed "s#${DB_PASSWORD}#***#g" app.conf
    EOT
  }
}

resource "kubernetes_service" "identity_access_manager_service" {
  metadata {
    name      = "identity-access-manager"
    namespace = var.namespace_name
  }
  spec {
    selector = {
      "app.kubernetes.io/part-of"   = "walrus"
      "app.kubernetes.io/component" = "identity-access-manager"
    }
    port {
      name        = "http"
      port        = 8000
      target_port = "http"
    }
  }
}

resource "kubernetes_deployment" "identity_access_manager_deployment" {
  metadata {
    name      = "identity-access-manager"
    namespace = var.namespace_name
    labels = {
      "app.kubernetes.io/part-of"   = "walrus"
      "app.kubernetes.io/component" = "identity-access-manager"
      "app.kubernetes.io/name"      = "casdoor"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        "app.kubernetes.io/part-of"   = "walrus"
        "app.kubernetes.io/component" = "identity-access-manager"
        "app.kubernetes.io/name"      = "casdoor"
      }
    }
    template {
      metadata {
        labels = {
          "app.kubernetes.io/part-of"   = "walrus"
          "app.kubernetes.io/component" = "identity-access-manager"
          "app.kubernetes.io/name"      = "casdoor"
        }
      }
      spec {
        automount_service_account_token = false
        restart_policy                  = "Always"
        init_container {
          name             = "init"
          image            = "sealio/casdoor:v1.515.0-seal.1"
          image_pull_policy = "IfNotPresent"
          working_dir      = "/tmp/conf"
          command          = ["/script/init.sh"]
          env {
            name = "DB_DRIVER"
            value_from {
              secret_key_ref {
                name = "walrus"
                key  = "db_driver"
              }
            }
          }
          env {
            name = "DB_USER"
            value_from {
              secret_key_ref {
                name = "walrus"
                key  = "db_user"
              }
            }
          }
          env {
            name = "DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = "walrus"
                key  = "db_password"
              }
            }
          }
          env {
            name = "DB_NAME"
            value_from {
              secret_key_ref {
                name = "walrus"
                key  = "db_name"
              }
            }
          }
          env {
            name  = "DB_SOURCE"
            value = "$(DB_DRIVER)://$(DB_USER):$(DB_PASSWORD)@database:5432/$(DB_NAME)?sslmode=disable"
          }
          volume_mount {
            name      = "script"
            mount_path = "/script"
          }
          volume_mount {
            name      = "config"
            mount_path = "/tmp/conf"
          }
        }
        container {
          name             = "casdoor"
          image            = "sealio/casdoor:v1.515.0-seal.1"
          image_pull_policy = "IfNotPresent"
          working_dir      = "/"
          command          = ["/casdoor", "--createDatabase=true"]
          resources {
            limits   = {
              cpu    = "2"
              memory = "4Gi"
            }
            requests = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
          port {
            name           = "http"
            container_port = 8000
          }
          startup_probe {
            failure_threshold = 10
            period_seconds    = 5
            tcp_socket {
              port = 8000
            }
          }
          readiness_probe {
            failure_threshold = 3
            timeout_seconds   = 5
            period_seconds    = 5
            tcp_socket {
              port = 8000
            }
          }
          liveness_probe {
            failure_threshold = 3
            timeout_seconds   = 5
            period_seconds    = 10
            tcp_socket {
              port = 8000
            }
          }
          volume_mount {
            name      = "config"
            mount_path = "/conf"
          }
          volume_mount {
            name      = "data"
            mount_path = "/var/run/casdoor"
          }
        }
        volume {
          name = "script"
          config_map {
            name = "identity-access-manager-script"
            default_mode = 0500
          }
        }
        volume {
          name = "config"
          empty_dir {}
        }
        volume {
          name = "data"
          empty_dir {}
        }
      }
    }
  }
}

#
# Walrus server
#
## RBAC for installing third-party applications.
##
## Since the installation of some third-party software has permission granting operations,
## it will contain some resource global operation permissions, but only for granting.
##

resource "kubernetes_service_account" "walrus_service_account" {
  metadata {
    name      = "walrus"
    namespace = var.namespace_name
    labels    = {
      "app.kubernetes.io/part-of"   = "walrus"
      "app.kubernetes.io/component" = "walrus"
    }
  }
}

resource "kubernetes_cluster_role" "walrus_cluster_role" {
  metadata {
    name = "walrus"
    labels = {
      "app.kubernetes.io/part-of"   = "walrus"
      "app.kubernetes.io/component" = "walrus"
    }
  }
  rule {
    api_groups = ["*"]
    resources  = ["*"]
    verbs      = ["*"]
  }
  rule {
    non_resource_urls = ["*"]
    verbs             = ["*"]
  }
}

resource "kubernetes_cluster_role_binding" "walrus_cluster_role_binding" {
  metadata {
    name = "walrus"
    labels = {
      "app.kubernetes.io/part-of"   = "walrus"
      "app.kubernetes.io/component" = "walrus"
    }
  }
  subject {
    kind      = "ServiceAccount"
    name      = "walrus"
    namespace = var.namespace_name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "walrus"
  }
}

resource "kubernetes_role" "walrus_enable_workflow_role" {
  metadata {
    name      = "walrus-enable-workflow"
    namespace = var.namespace_name
    labels    = {
      "app.kubernetes.io/part-of"   = "walrus"
      "app.kubernetes.io/component" = "walrus"
    }
  }
  rule {
    api_groups = ["argoproj.io"]
    resources  = ["*"]
    verbs      = ["*"]
  }
  rule {
    api_groups = [""]
    resources  = [
      "persistentvolumeclaims",
      "persistentvolumeclaims/finalizers"
    ]
    verbs      = ["*"]
  }
  rule {
    api_groups = [""]
    resources  = ["pods/exec"]
    verbs      = ["*"]
  }
  rule {
    api_groups = ["policy"]
    resources  = ["poddisruptionbudgets"]
    verbs      = ["*"]
  }
}

resource "kubernetes_role_binding" "walrus_enable_workflow_role_binding" {
  metadata {
    name      = "walrus-enable-workflow"
    namespace = var.namespace_name
    labels    = {
      "app.kubernetes.io/part-of"   = "walrus"
      "app.kubernetes.io/component" = "walrus"
    }
  }
  subject {
    kind      = "ServiceAccount"
    name      = "walrus"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "walrus-enable-workflow"
  }
}

#
## RBAC for deploying
##
## As limiting in the walrus-system, it can be safe to make all verbs as "*".
#

resource "kubernetes_service_account" "walrus_deployer" {
  metadata {
    name      = "walrus-deployer"
    namespace = var.namespace_name
    labels    = {
      "app.kubernetes.io/part-of"   = "walrus"
      "app.kubernetes.io/component" = "walrus"
    }
  }
}

resource "kubernetes_role" "walrus_deployer_role" {
  metadata {
    name      = "walrus-deployer"
    namespace = var.namespace_name
    labels    = {
      "app.kubernetes.io/part-of"   = "walrus"
      "app.kubernetes.io/component" = "walrus"
    }
  }
  rule {
    api_groups = ["batch"]
    resources  = ["jobs"]
    verbs      = ["*"]
  }
  rule {
    api_groups = [""]
    resources  = [
      "secrets",
      "pods",
      "pods/log"
    ]
    verbs      = ["*"]
  }
}

resource "kubernetes_role_binding" "walrus_deployer_role_binding" {
  metadata {
    name      = "walrus-deployer"
    namespace = var.namespace_name
    labels    = {
      "app.kubernetes.io/part-of"   = "walrus"
      "app.kubernetes.io/component" = "walrus"
    }
  }
  subject {
    kind      = "ServiceAccount"
    name      = "walrus-deployer"
    namespace = var.namespace_name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "walrus-deployer"
  }
}

#
## RBAC for running workflow
##
## As limiting in the walrus-system, it can be safe to make all verbs as "*".
#

resource "kubernetes_service_account" "walrus_workflow" {
  metadata {
    name      = "walrus-workflow"
    namespace = var.namespace_name
    labels    = {
      "app.kubernetes.io/part-of"   = "walrus"
      "app.kubernetes.io/component" = "walrus"
    }
  }
}

resource "kubernetes_role" "walrus_workflow_role" {
  metadata {
    name      = "walrus-workflow"
    namespace = var.namespace_name
    labels    = {
      "app.kubernetes.io/part-of"   = "walrus"
      "app.kubernetes.io/component" = "walrus"
    }
  }
  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "watch", "patch"]
  }
  rule {
    api_groups = [""]
    resources  = ["pods/logs"]
    verbs      = ["get", "watch"]
  }
  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get"]
  }
  rule {
    api_groups = ["argoproj.io"]
    resources  = ["workflowtasksets"]
    verbs      = ["watch", "list"]
  }
  rule {
    api_groups = ["argoproj.io"]
    resources  = ["workflowtaskresults"]
    verbs      = ["create", "patch"]
  }
  rule {
    api_groups = ["argoproj.io"]
    resources  = ["workflowtasksets/status"]
    verbs      = ["patch"]
  }
}

resource "kubernetes_role_binding" "walrus_workflow_role_binding" {
  metadata {
    name      = "walrus-workflow"
    namespace = var.namespace_name
    labels    = {
      "app.kubernetes.io/part-of"   = "walrus"
      "app.kubernetes.io/component" = "walrus"
    }
  }
  subject {
    kind      = "ServiceAccount"
    name      = "walrus-workflow"
    namespace = var.namespace_name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "walrus-workflow"
  }
}

#
## Storage
#

resource "kubernetes_persistent_volume_claim" "walrus_pvc" {
  metadata {
    name      = "walrus"
    namespace = var.namespace_name
    labels    = {
      "app.kubernetes.io/part-of"   = "walrus"
      "app.kubernetes.io/component" = "walrus"
    }
  }
  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests  = {
        storage = "500Mi"
      }
    }
  }
}

#
## Service
#

resource "kubernetes_service" "walrus_service" {
  metadata {
    name      = "walrus"
    namespace = var.namespace_name
    labels    = {
      "app.kubernetes.io/part-of"   = "walrus"
      "app.kubernetes.io/component" = "walrus"
    }
  }
  spec {
    selector = {
      "app.kubernetes.io/part-of"   = "walrus"
      "app.kubernetes.io/component" = "walrus"
    }
    session_affinity = "ClientIP"
    type             = "NodePort"
    port {
      name       = "http"
      port       = 80
      target_port = "http"
    }
    port {
      name       = "https"
      port       = 443
      target_port = "https"
    }
  }
}

#
## Deployment
#

resource "kubernetes_deployment" "walrus_server" {
  metadata {
    name      = "walrus"
    namespace = var.namespace_name
    labels    = {
      "app.kubernetes.io/part-of"   = "walrus"
      "app.kubernetes.io/component" = "walrus"
      "app.kubernetes.io/name"      = "walrus-server"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        "app.kubernetes.io/part-of"   = "walrus"
        "app.kubernetes.io/component" = "walrus"
        "app.kubernetes.io/name"      = "walrus-server"
      }
    }
    template {
      metadata {
        labels = {
          "app.kubernetes.io/part-of"   = "walrus"
          "app.kubernetes.io/component" = "walrus"
          "app.kubernetes.io/name"      = "walrus-server"
        }
      }
      spec {
        affinity {
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 100
              pod_affinity_term {
                topology_key = "kubernetes.io/hostname"
                label_selector {
                  match_expressions {
                    key      = "app.kubernetes.io/component"
                    operator = "In"
                    values  = ["walrus"]
                  }
                  match_expressions {
                    key      = "app.kubernetes.io/part-of"
                    operator = "In"
                    values  = ["walrus"]
                  }
                  match_expressions {
                    key      = "app.kubernetes.io/name"
                    operator = "In"
                    values  = ["walrus-server"]
                  }
                }
              }
            }
          }
        }
        restart_policy       = "Always"
        service_account_name = "walrus"
        container {
          name  = "walrus-server"
          image = "sealio/walrus:v0.6.0"
          image_pull_policy = "Always"
          resources {
            limits   = {
              cpu    = "4"
              memory = "8Gi"
            }
            requests = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
          env {
            name  = "DB_DRIVER"
            value_from {
              secret_key_ref {
                name = "walrus"
                key  = "db_driver"
              }
            }
          }
          env {
            name  = "DB_USER"
            value_from {
              secret_key_ref {
                name = "walrus"
                key  = "db_user"
              }
            }
          }
          env {
            name  = "DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = "walrus"
                key  = "db_password"
              }
            }
          }
          env {
            name  = "DB_NAME"
            value_from {
              secret_key_ref {
                name = "walrus"
                key  = "db_name"
              }
            }
          }
          env {
            name  = "MINIO_ROOT_USER"
            value_from {
              secret_key_ref {
                name = "walrus"
                key  = "minio_root_user"
              }
            }
          }
          env {
            name  = "MINIO_ROOT_PASSWORD"
            value_from {
              secret_key_ref {
                name = "walrus"
                key  = "minio_root_password"
              }
            }
          }
          env {
            name  = "MINIO_BUCKET"
            value_from {
              secret_key_ref {
                name = "walrus"
                key  = "minio_bucket"
              }
            }
          }
          env {
            name  = "SERVER_SETTING_LOCAL_ENVIRONMENT_MODE"
            value_from {
              secret_key_ref {
                name = "walrus"
                key  = "local_environment_mode"
              }
            }
          }
          env {
            name  = "SERVER_ENABLE_TLS"
            value_from {
              secret_key_ref {
                name = "walrus"
                key  = "enable_tls"
              }
            }
          }
          env {
            name  = "SERVER_DATA_SOURCE_ADDRESS"
            value = "${DB_DRIVER}://${DB_USER}:${DB_PASSWORD}@database:5432/${DB_NAME}?sslmode=disable"
          }
          env {
            name  = "SERVER_CASDOOR_SERVER"
            value = "http://identity-access-manager:8000"
          }
          port {
            name           = "http"
            container_port = 80
          }
          port {
            name           = "https"
            container_port = 443
          }
          startup_probe {
            failure_threshold = 10
            period_seconds    = 5
            http_get {
              path = "/readyz"
              port = 80
            }
          }
          readiness_probe {
            failure_threshold = 3
            timeout_seconds   = 5
            period_seconds    = 5
            http_get {
              path = "/readyz"
              port = 80
            }
          }
          liveness_probe {
            failure_threshold = 10
            timeout_seconds   = 5
            period_seconds    = 10
            http_get {
              path = "/livez"
              port = 80
              http_header {
                name  = "User-Agent"
                value = ""
              }
            }
          }
          volume_mount {
            name      = "custom-tls"
            mount_path = "/etc/walrus/ssl"
          }
          volume_mount {
            name      = "data"
            mount_path = "/var/run/walrus"
          }
        }
        volume {
          name = "custom-tls"
          secret {
            secret_name = "walrus-custom-tls"
            optional    = true
          }
        }
        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = "walrus"
          }
        }
      }
    }
  }
}
