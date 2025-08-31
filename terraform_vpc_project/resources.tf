# Load Balancer
resource "aws_lb" "app_lb" {
  name               = "my-app-lb"
  internal           = false  # Public
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
  enable_deletion_protection = false

  tags = {
    Name = "App Load Balancer"
  }
}

# Target Group for ALB
resource "aws_lb_target_group" "app_target_group" {
  name     = "my-app-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "App Target Group"
  }
}

# Load Balancer Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.app_target_group.arn
    type             = "forward"
  }

  tags = {
    Name = "HTTP Listener"
  }
}

# Key Pair
resource "aws_key_pair" "ec2_key" {
  key_name   = "my-ec2-key"
  public_key = file("~/.ssh/YOUR_PUBLIC_KEY.pub")  # or absolute path  # Make sure this file exists
}

output "debug_public_key" {
  value = file("~/.ssh/YOUR_PUBLIC_KEY.pub")
}

# IAM Role for Bastion Host
resource "aws_iam_role" "bastion_role" {
  name = "bastion-ec2-readonly-role"

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

resource "aws_iam_role_policy_attachment" "bastion_role_attach" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

resource "aws_iam_instance_profile" "bastion_instance_profile" {
  name = "bastion-ec2-readonly-instance-profile"
  role = aws_iam_role.bastion_role.name
}

# Elastic IP for Bastion Host
resource "aws_eip" "bastion_eip" {
  instance = aws_instance.bastion_host.id
}

# Bastion Host
resource "aws_instance" "bastion_host" {
  ami                         = "ami-0e2c86481225d3c51"  # Amazon Linux 2 (us-east-1)
  instance_type               = "t2.micro"               # Free Tier instance type
  subnet_id                   = aws_subnet.public_subnet_1.id  # Use existing public subnet
  key_name                    = aws_key_pair.ec2_key.key_name
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]  # Use the ID, not the name
  iam_instance_profile        = aws_iam_instance_profile.bastion_instance_profile.name
  associate_public_ip_address = true  # Assign public IP for SSH access

  tags = {
    Name = "BastionHost"
  }
}

 

# Autoscaling Group (using Launch Template)
resource "aws_autoscaling_group" "asg" {
  name = "ASG-EC2"
  desired_capacity          = 2
  max_size                  = 4
  min_size                  = 2
  vpc_zone_identifier       = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
  target_group_arns         = [aws_lb_target_group.app_target_group.arn]
  health_check_type         = "EC2"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app_launch_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "ASG-EC2"
    propagate_at_launch = true
  }
}

# Launch Template (replaces Launch Configuration)
resource "aws_launch_template" "app_launch_template" {
  name_prefix   = "app-launch-template-"
  image_id      = "ami-0e2c86481225d3c51"
  instance_type = "t3.micro"
  key_name      = aws_key_pair.ec2_key.key_name

  user_data = base64encode(<<-EOT
#!/bin/bash
yum update -y
yum install -y python3
mkdir -p /var/www/html
HOSTNAME=$(hostname)
echo "Hostname: $HOSTNAME" > /var/www/html/index.html
nohup python3 -m http.server 80 --directory /var/www/html &
EOT
  )

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]  
}

# Autoscaling Policies
resource "aws_autoscaling_policy" "scale_out" {
  name                   = "scale-out-policy"
  autoscaling_group_name = aws_autoscaling_group.asg.name
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
}

resource "aws_autoscaling_policy" "scale_in" {
  name                   = "scale-in-policy"
  autoscaling_group_name = aws_autoscaling_group.asg.name
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "high-cpu-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 70
  alarm_actions       = [aws_autoscaling_policy.scale_out.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }
}

resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "low-cpu-alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 30
  alarm_actions       = [aws_autoscaling_policy.scale_in.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }
}

variable "db_password" {
  description = "Password for the RDS instance"
  type        = string
}



# RDS Instance
resource "aws_db_instance" "rds" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.m5.large"
  db_name              = "mydb"
  username             = "admin"
  password             = var.db_password
  db_subnet_group_name = aws_db_subnet_group.my_db_subnet_group.name

  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  multi_az             = true
  publicly_accessible  = false
  skip_final_snapshot  = true

  tags = {
    Name = "RDS-Instance"
  }
}

# DB Subnet Group
resource "aws_db_subnet_group" "my_db_subnet_group" {
  name       = "my-db-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]

  tags = {
    Name = "MyDBSubnetGroup"
  }
}
