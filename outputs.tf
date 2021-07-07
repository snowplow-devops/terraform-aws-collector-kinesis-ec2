output "asg_id" {
  value       = aws_autoscaling_group.asg.id
  description = "ID of the ASG"
}

output "asg_name" {
  value       = aws_autoscaling_group.asg.name
  description = "Name of the ASG"
}

output "sg_id" {
  value       = aws_security_group.sg.id
  description = "ID of the security group attached to the Collector Server node"
}
