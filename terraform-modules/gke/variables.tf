variable "project_id" {
  type = string
}

variable "project_region" {
  type = string
}

variable "project_zones" {
  type    = list(string)
  default = []
}

variable "project_cidr" {
  type    = string
}

variable "environment" {
  type    = string
  default = ""
}

variable "cluster_name" {
  type    = string
  default = ""
}

variable "default_node_pool_machine_type" {
  type    = string
  default = "n1-standard-1"
}

variable "default_node_pool_preemptible" {
  type    = bool
  default = false
}

variable "default_node_pool_name" {
  type    = string
  default = "default-node-pool"
}

variable "default_node_pool_node_count" {
  type    = number
  default = 3
}

variable "default_node_pool_min_node_count" {
  type    = number
  default = 1
}

variable "default_node_pool_max_node_count" {
  type    = number
  default = 5
}

variable "gpu_node_pool_name" {
  type    = string
  default = "gpu-node-pool"
}

variable "gpu_node_pool_min_node_count" {
  type    = number
  default = 0
}

variable "gpu_node_pool_max_node_count" {
  type    = number
  default = 5
}

variable "gpu_node_pool_initial_node_count" {
  type    = number
  default = 0
}

variable "gpu_node_pool_preemptible" {
  type    = bool
  default = false
}

variable "gpu_node_pool_machine_type" {
  type    = string
  default = "n1-standard-2"
}
