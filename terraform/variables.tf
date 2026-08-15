variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "ap-south-1"
}

variable "cluster_name" {
  description = "EKS Cluster Name"
  type        = string
  default     = "devops-ai-eks"
}

variable "node_instance_type" {
  description = "EC2 Instance type for the managed node group"
  type        = string
  default     = "t3.small"
}