# Bastion security group. SSH ingress is restricted to the
# administrator's current public IPv4 address.

resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-bastion-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  security_group_id = aws_security_group.bastion.id

  description = "SSH access from administrator IP"
  cidr_ipv4   = var.admin_ip_cidr
  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "bastion_outbound" {
  security_group_id = aws_security_group.bastion.id

  description = "Allow outbound IPv4 traffic"
  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}

resource "aws_key_pair" "bastion" {
  key_name   = "${var.project_name}-bastion-key"
  public_key = file(pathexpand("~/.ssh/bastion-key.pub"))

  tags = {
    Name = "${var.project_name}-bastion-key"
  }
}

# Latest Amazon Linux 2023 AMI for x86_64
data "aws_ssm_parameter" "bastion_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# Launch template defines how the ASG creates replacement bastions.
# IMDSv2 is required, storage is encrypted, and user-data attaches the Elastic IP.
resource "aws_launch_template" "bastion" {
  name_prefix   = "${var.project_name}-bastion-"
  image_id      = data.aws_ssm_parameter.bastion_ami.value
  instance_type = "t3.micro"
  key_name      = aws_key_pair.bastion.key_name

  update_default_version = true

  user_data = base64encode(templatefile("${path.module}/bastion-user-data.sh", {
    allocation_id = aws_eip.bastion.id
    region        = var.aws_region
  }))

  iam_instance_profile {
    name = aws_iam_instance_profile.bastion.name
  }

  network_interfaces {
    device_index                = 0
    associate_public_ip_address = true
    security_groups             = [aws_security_group.bastion.id]
    delete_on_termination       = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 8
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.project_name}-bastion"
      Role = "bastion"
    }
  }
}


resource "aws_iam_role" "bastion" {
  name = "${var.project_name}-bastion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.project_name}-bastion-profile"
  role = aws_iam_role.bastion.name
}


resource "aws_eip" "bastion" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-bastion-eip"
  }
}


data "aws_caller_identity" "current" {}

# Restricts Elastic IP association permissions to the project EIP and tagged bastion instances.
resource "aws_iam_role_policy" "bastion_eip" {
  name = "${var.project_name}-bastion-eip-policy"
  role = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ec2:AssociateAddress"
        Resource = aws_eip.bastion.arn
      },
      {
        Effect   = "Allow"
        Action   = "ec2:AssociateAddress"
        Resource = "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:instance/*"

        Condition = {
          StringEquals = {
            "ec2:ResourceTag/Role" = "bastion"
          }
        }
      }
    ]
  })
}


# Maintains one bastion across two Availability Zones for automatic replacement.
resource "aws_autoscaling_group" "bastion" {
  name = "${var.project_name}-bastion-asg"

  min_size         = 1
  max_size         = 1
  desired_capacity = 1

  vpc_zone_identifier = aws_subnet.public[*].id

  health_check_type         = "EC2"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.bastion.id
    version = aws_launch_template.bastion.latest_version
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-bastion"
    propagate_at_launch = true
  }

  tag {
    key                 = "Role"
    value               = "bastion"
    propagate_at_launch = true
  }

  depends_on = [
    aws_iam_role_policy.bastion_eip
  ]
}
