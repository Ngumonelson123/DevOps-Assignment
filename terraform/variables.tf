variable "aws_region" {
  default = "us-east-1"
}
variable "key_pair" {
  description = "SSH key pair name"
    type        = string
}
variable "instance_type" {
  description = "EC2 instance type"
  default     = "t2.micro"
  
}
variable "public_key_path" {
  description = "Path to the public SSH key"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed for SSH access"
  type        = string
  default     = "0.0.0.0/0"
}