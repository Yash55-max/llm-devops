output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.llm_node.public_ip
}

output "ssh_command" {
  description = "Command to SSH directly into the instance"
  value       = "ssh -i ~/.ssh/llm_ec2_key ubuntu@${aws_instance.llm_node.public_ip}"
}