# Security Group for the Bastion Host (Allows only SSH from your IP)
resource "aws_security_group" "bastion_sg" {
  name        = "bastion_sg"
  description = "Security Group for Bastion Host"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["YOUR.PUBLIC.IP/32"]  # Replace with your public IP
  } 

  # Rule to allow ping (ICMP Echo Request)
  ingress {
    from_port   = -1        # For ICMP, use -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.0.0.0/16"]  # Replace with your VPC CIDR or private EC2 subnet
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "bastion_sg_id" {
  description = "ID of the security group for the bastion host"
  value       = aws_security_group.bastion_sg.id
}

# Security Group for the Load Balancer
resource "aws_security_group" "lb_sg" {
  name        = "lb_sg"
  description = "Security Group for the Load Balancer"
  vpc_id      = aws_vpc.main.id

  # Allow incoming HTTP traffic (port 80)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow traffic from any IP
  }

  # Allow incoming HTTPS traffic (port 443)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow traffic from any IP
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for EC2
resource "aws_security_group" "ec2_sg" {
  name        = "ec2_sg"
  description = "Security Group for EC2 instances"
  vpc_id      = aws_vpc.main.id

  # Allow SSH (port 22) from the Bastion Host
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]  # Accept SSH connections from Bastion Host SG
  }

  # Allow ICMP (ping) ONLY from the Bastion Host
  ingress {
    from_port   = -1         # ICMP uses -1 for "all ICMP types"
    to_port     = -1
    protocol    = "icmp"
    security_groups = [aws_security_group.bastion_sg.id]  # Only from the Bastion Host SG
  }

  # Allow HTTP traffic (port 80) from the Load Balancer
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.lb_sg.id]  # Accept HTTP traffic from the Load Balancer
  }

  # Allow HTTPS traffic (port 443) from the Load Balancer
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    security_groups = [aws_security_group.lb_sg.id]  # Accept HTTPS traffic from the Load Balancer
  }

  # Allow all outbound traffic (to Internet, RDS, etc.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # Allow all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for RDS (only allows traffic from EC2 in private subnets)
resource "aws_security_group" "rds_sg" {
  name        = "rds_sg"
  description = "Security Group for RDS"
  vpc_id      = aws_vpc.main.id

  # Allow MySQL traffic (port 3306) incoming from private EC2
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]  # Only from private EC2
  }
  
  # Allow all outbound traffic to private subnets (10.0.3.0/24 and 10.0.4.0/24)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # Allow all outbound traffic
    cidr_blocks = ["10.0.3.0/24", "10.0.4.0/24"]  # Only to private subnets
  }
}
