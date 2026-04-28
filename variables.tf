# Variables
variable "vpc_id" {
  description = "VPC ID where Redis cluster will be deployed"
  type        = string
  default     = "vpc-XXX"
}

variable "subnet_ids" {
  description = "Subnet IDs for Redis cluster"
  type        = list(string)
  default     = ["subnet-XXX", "subnet-XXX"]
}

variable "stage_ip" {
  description = "Stage environment IP"
  type        = string
  default     = "XX.XX.XX.XX"
}

variable "prod_ip" {
  description = "Production environment IP"
  type        = string
  default     = "XX.XX.XX.XX"
}

