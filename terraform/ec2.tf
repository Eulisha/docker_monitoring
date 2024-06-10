data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

# resource "aws_spot_instance_request" "cheap_worker" {
#   ami             = data.aws_ami.ubuntu.id
#   instance_type   = "t3.micro"
#   spot_price      = "0.0045"
#   key_name        = aws_key_pair.euli.key_name
#   security_groups = [aws_security_group.allow_inbound.name]
#   tags = {
#     Name = "cheap_worker"
#   }
#   user_data = file("user_data.sh")
# }
resource "aws_instance" "cheap_worker" {
  ami = data.aws_ami.ubuntu.id
  instance_market_options {
    market_type = "spot"
    spot_options {
      max_price = "0.0045"
    }
  }
  instance_type   = "t3.micro"
  key_name        = aws_key_pair.euli.key_name
  security_groups = [aws_security_group.allow_inbound.name]
  tags = {
    Name = "cheap_worker"
  }
  user_data = file("user_data.sh")
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "allow_inbound" {
  name        = "allow_inbound"
  description = "Allow inbound traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow inbound traffic from cAdvisor"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow inbound traffic from Prometheus"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow inbound traffic from Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow inbound traffic from Grafana"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 9323
    to_port     = 9323
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "euli" {
  key_name   = "euli"
  public_key = file("~/.ssh/euli-github.pub")
}

# scp docker folder to the instance
resource "null_resource" "scp_docker" {
  depends_on = [aws_instance.cheap_worker]
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("~/.ssh/euli-github")
    host        = aws_instance.cheap_worker.public_ip
  }
  provisioner "file" {
    source      = "../docker"
    destination = "/home/ubuntu"
  }
  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait",
      "cd /home/ubuntu/docker && docker compose up -d"
    ]
  }
}

output "ssh_info" {
  depends_on = [aws_instance.cheap_worker]
  value      = "ssh -i ~/.ssh/euli-github ubuntu@${aws_instance.cheap_worker.public_ip}"
}

