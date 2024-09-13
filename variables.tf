#
# Contextual Fields
#

variable "context" {
  description = <<-EOF
Receive contextual information. When Walrus deploys, Walrus will inject specific contextual information into this field.

Examples:
```
context:
  project:
    name: string
    id: string
  environment:
    name: string
    id: string
  resource:
    name: string
    id: string
```
EOF
  type        = map(any)
  default     = {}
}

#
# Walrus varibales
#

variable "namespace_name" {
  description = "The Kubernetes namespace where the resources will be created."
  type        = string
  default     = "walrus-system"
}

variable "host" {
  description = "The host for the database connection."
  type        = string
  default     = "walrus.yourdomain.com"
}

variable "username" {
  description = "The username for the database connection."
  type        = string
  default     = "admin"
}

variable "password" {
  description = "The password for the database connection."
  type        = string
  sensitive   = true
}

#
# Origin CA ingress variables
#

variable "issuer" {
  description = "The name of the issuer used by Cert-Manager to issue the certificate."
  type        = string
  default     = "origin-ca-issuer-hv"
}

variable "issuer_kind" {
  description = "The kind of issuer used by Cert-Manager, such as ClusterIssuer or other custom issuers."
  type        = string
  default     = "OriginIssuer"
}

variable "issuer_group" {
  description = "The group of the issuer, which organizes different CRDs like the ones from Cloudflare."
  type        = string
  default     = "cert-manager.k8s.cloudflare.com"
}

variable "ingress_class_name" {
  description = "The name of the ingress class to be used for routing traffic. Typically specifies the type of ingress controller, like nginx or traefik."
  type        = string
  default     = "nginx"
}

variable "secret_name" {
  description = "The name of the Kubernetes secret that stores the TLS certificate for the Walrus ingress."
  type        = string
  default     = "walrus-yourdomain-com"
}