#
# Contextual output
#

output "walrus_project_name" {
  value       = try(local.context["project"]["name"], null)
  description = "The name of project where deployed in Walrus."
}

output "walrus_project_id" {
  value       = try(local.context["project"]["id"], null)
  description = "The id of project where deployed in Walrus."
}

output "walrus_environment_name" {
  value       = try(local.context["environment"]["name"], null)
  description = "The name of environment where deployed in Walrus."
}

output "walrus_environment_id" {
  value       = try(local.context["environment"]["id"], null)
  description = "The id of environment where deployed in Walrus."
}

output "walrus_resource_name" {
  value       = try(local.context["resource"]["name"], null)
  description = "The name of resource where deployed in Walrus."
}

output "walrus_resource_id" {
  value       = try(local.context["resource"]["id"], null)
  description = "The id of resource where deployed in Walrus."
}


#
# Walrus output
#

# output "service_account_walrus" {
#   description = "The ServiceAccount used by the Walrus application."
#   value = kubernetes_service_account.walrus_service_account
# }

# output "cluster_role_walrus" {
#   description = "The ClusterRole that grants global permissions to the Walrus application."
#   value = kubernetes_cluster_role.walrus_cluster_role
# }

# output "cluster_role_binding_walrus" {
#   description = "The ClusterRoleBinding that binds the Walrus ServiceAccount to the ClusterRole."
#   value = kubernetes_cluster_role_binding.walrus_cluster_role_binding
# }

# output "role_walrus_enable_workflow" {
#   description = "The Role that grants permissions for enabling workflows within the Walrus namespace."
#   value = kubernetes_role.walrus_enable_workflow_role
# }

# output "role_binding_walrus_enable_workflow" {
#   description = "The RoleBinding that binds the Walrus ServiceAccount to the Role for enabling workflows."
#   value = kubernetes_role_binding.walrus_enable_workflow_role_binding
# }

# output "service_account_walrus_deployer" {
#   description = "The ServiceAccount used by the Walrus deployer."
#   value = kubernetes_service_account.walrus_deployer
# }

# output "role_walrus_deployer" {
#   description = "The Role that grants permissions to deploy applications within the Walrus namespace."
#   value = kubernetes_role.walrus_deployer_role
# }

# output "role_binding_walrus_deployer" {
#   description = "The RoleBinding that binds the Walrus deployer ServiceAccount to the Role."
#   value = kubernetes_role_binding.walrus_deployer_role_binding
# }

# output "service_account_walrus_workflow" {
#   description = "The ServiceAccount used for running workflows in the Walrus namespace."
#   value = kubernetes_service_account.walrus_workflow
# }

# output "role_walrus_workflow" {
#   description = "The Role that grants permissions for running workflows within the Walrus namespace."
#   value = kubernetes_role.walrus_workflow_role
# }

# output "role_binding_walrus_workflow" {
#   description = "The RoleBinding that binds the Walrus workflow ServiceAccount to the Role for running workflows."
#   value = kubernetes_role_binding.walrus_workflow_role_binding
# }

# output "persistent_volume_claim_walrus" {
#   description = "The PersistentVolumeClaim used for storage by the Walrus application."
#   value = kubernetes_persistent_volume_claim.database_pvc
# }

# output "persistent_volume_claim_minio" {
#   description = "The PersistentVolumeClaim used for storage by the Minio application."
#   value = kubernetes_persistent_volume_claim.minio_pvc
# }

# output "persistent_volume_claim_walrus" {
#   description = "The PersistentVolumeClaim used for storage by the Walrus VPC application."
#   value = kubernetes_persistent_volume_claim.walrus_pvc
# }

# output "service_walrus" {
#   description = "The Service exposing the Walrus application, including HTTP and HTTPS ports."
#   value = kubernetes_service.
# }

# output "deployment_walrus" {
#   description = "The Deployment for the Walrus application, including configuration for replicas, resource requests/limits, and probes."
#   value = kubernetes_deployment.walrus
# }


#
# Submodule output
#

output "submodule" {
  value       = module.submodule.message
  description = "The message from submodule."
}
