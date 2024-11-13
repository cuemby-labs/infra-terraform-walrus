#
# Walrus Variables
#

variable "namespace_name" {
  description = "The namespace where resources will be created."
  type        = string
  default     = "walrus-system"
}

#
# Ingress variables
#


variable "domain_name" {
  description = "Domain name."
  type        = string
  default     = "dev.domain.com"
}

variable "issuer_name" {
  type        = string
  description = "Origin issuer name"
  default     = "origin-ca-issuer"
}

variable "issuer_kind" {
  type        = string
  description = "Origin issuer kind"
  default     = "ClusterOriginIssuer"
}

#
# Walrus Contextual Fields Variable
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