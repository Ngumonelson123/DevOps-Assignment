output "web_server_ip" {
  value = aws_instance.web_server.public_ip
}

output "proxy_server_ip" {
  value = aws_instance.proxy_server.public_ip
}

output "web_server_private_ip" {
  value = aws_instance.web_server.private_ip
}