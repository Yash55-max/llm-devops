output "cluster_name" {
  description = "EKS Cluster Name"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS Control Plane Endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "kubeconfig_cmd" {
  description = "Command to authenticate kubectl with the EKS cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name${aws_eks_cluster.main.name}"
}