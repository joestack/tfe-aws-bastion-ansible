variable "aws_region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "owner" {
  description = "Owner of this deployment"
}

variable "name" {
  description = "Name of this deployment"
}

variable "ttl" {
  description = "Time to live before destroyed"
}

variable "key_name" {
  description = "private ssh id_rsa key to be used to access the nodes from the bastion host"
}

variable "id_rsa_aws" {
  description = "public ssh key used to access the bastion host"
}

variable "dns_domain" {
  description = "DNS domain suffix"
  default     = "joestack.xyz"
}

variable "network_address_space" {
  description = "CIDR for this deployment"
  default     = "192.168.0.0/16"
}

variable "ssh_user" {
  description = "default ssh user to get access to an instance"
  default     = "ubuntu"
}

locals {
  mod_az = length(
    split(",", join(", ", data.aws_availability_zones.available.names)),
  )
}

variable "web_subnet_count" {
  description = "amount of subnets to be used for working nodes"
  default     = "2"
}

variable "web_node_count" {
  description = "amount of worker nodes"
  default     = "2"
}

variable "instance_type" {
  description = "instance size to be used for worker nodes"
  default     = "t2.small"
}

