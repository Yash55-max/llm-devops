variable "aws_region" {
  description = "AWS Region to deploy resources"
  type        = string
  default     = "ap-south-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"   # or "t3.micro"
}

variable "public_key_path" {
  description = "Path to the public SSH key"
  type        = string
  default     = "~/.ssh/llm_ec2_key.pub"
}