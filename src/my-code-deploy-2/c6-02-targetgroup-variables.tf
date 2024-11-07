#variable "green_target_group_label" {
#    description = "The label of the target group for the green environment"
#    type = string
#    default = "green"
#}
#
#variable "blue_target_group_label" {
#  description = "The label of the target group for the blue environment"
#  type = string
#  default = "blue"
#}
#
#variable "target_group_port" {
#  type        = number
#  description = "The port for the default target group"
#}
#
#variable "target_group_target_type" {
#  type        = string
#  description = "The type (`instance`, `ip` or `lambda`) of targets that can be registered with the target group"
#}
#
#variable "target_group_protocol" {
#  type        = string
#  description = "The protocol for the default target group HTTP or HTTPS"
#}
#
#variable "deregistration_delay" {
#  type        = number
#  description = "The amount of time to wait in seconds while deregistering target"
#}
#
#
#
#variable "health_check_path" {
#  type        = string
#  description = "The destination for the health check request"
#  default = "/"
#}
#
#variable "health_check_port" {
#  type        = string
#  description = "The port to use for the healthcheck"
#  default = "8080"
#}
#
#variable "health_check_timeout" {
#  type        = number
#  description = "The amount of time to wait in seconds before failing a health check request"
#  default = 5
#}
#
#variable "health_check_healthy_threshold" {
#  type        = number
#  description = "The number of consecutive health checks successes required before healthy"
#  default = 2
#}
#
#variable "health_check_unhealthy_threshold" {
#  type        = number
#  description = "The number of consecutive health check failures required before unhealthy"
#  default = 2
#}
#
#variable "health_check_interval" {
#  type        = number
#  description = "The duration in seconds in between health checks"
#  default = 10
#}
#
#variable "health_check_matcher" {
#  type        = string
#  description = "The HTTP response codes to indicate a healthy check"
#  default = "200"
#}