#
# Origin CA Resources
#

resource "kubernetes_namespace" "walrus_system" {
  metadata {
    name = var.namespace_name
  }
}

data "template_file" "manifest_template" {
  
  template = file("${path.module}/values.yaml.tpl")
  vars     = {
    namespace_name   = var.namespace_name,
    issuer_name      = var.issuer_name,
    issuer_kind      = var.issuer_kind,
    dash_domain_name = local.dash_domain_name
  }
}

data "kubectl_file_documents" "manifest_files" {

  content = data.template_file.manifest_template.rendered
}

resource "kubectl_manifest" "apply_manifests" {

  for_each  = data.kubectl_file_documents.manifest_files.manifests
  yaml_body = each.value
}

#
# Walrus Information
#

locals {
  context          = var.context
  dash_domain_name = replace(var.domain_name, ".", "-")
}

module "submodule" {
  source = "./modules/submodule"

  message = "Hello, submodule"
}