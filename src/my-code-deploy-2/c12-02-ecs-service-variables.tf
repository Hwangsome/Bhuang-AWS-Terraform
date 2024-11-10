variable "task_definition" {
  type        = string
  description = "Reuse an existing task definition family and revision for the ecs service instead of creating one"
  default     = null
}