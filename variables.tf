variable "log_group_name" {
  description = "The name of the CloudWatch log group"
  type        = string
  default = "/ecs/app-first-task"
}

variable "retention_days" {
  description = "The number of days to retain the logs in the CloudWatch log group"
  type        = number
  default     = 7
}