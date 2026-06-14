variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "app_service_plan_name" {
  type = string
}

variable "app_service_name" {
  type = string
}

variable "sku_name" {
  type    = string
  default = "S1"
}

variable "runtime_stack" {
  type        = string
  description = "e.g. 'NODE|18-lts' or 'PYTHON|3.11'"
}

variable "tags" {
    type = map(string)
    description = "A map of tags to assign to the resources"
    default = {}
    }
