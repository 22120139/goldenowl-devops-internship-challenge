variable "aws_region" {
  description = "AWS region used to deploy resources"
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Name used for project resources"
  type        = string
  default     = "goldenowl-devops"
}

variable "instance_type" {
  description = "EC2 instance type used to run the application"
  type        = string
  default     = "t3.micro"
}

variable "image_tag" {
  description = "Initial ECR image tag used to bootstrap Auto Scaling instances"
  type        = string

  validation {
    condition     = length(var.image_tag) == 40
    error_message = "image_tag must be a full 40-character Git commit SHA."
  }
}