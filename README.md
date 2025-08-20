 🌐 Terraform AWS VPC Infrastructure

This repository contains a fully featured, high-availability AWS VPC infrastructure setup using **Terraform**. The project is modular and production-ready, following best practices like **remote state management**, **state locking**, and **multi-AZ deployment**.

---

## 📁 Project Structure

project-root/
│
├── terraform-backend-setup/ # Contains only backend configuration (S3 + DynamoDB)
│ └── main.tf # Defines S3 bucket for remote state and DynamoDB table for state locking
│
└── terraform_vpc_project/ # Main infrastructure code
├── backend-config.tf # "terraform" block that configures the remote backend (S3 + DynamoDB)
├── main.tf # Base VPC configuration and general resources
├── subnet.tf # Public and private subnet definitions (multi-AZ)
├── security.tf # Security groups and firewall rules
└── resources.tf # Application resources (e.g., EC2 instances, RDS, Load Balancer)

---

## 🚀 Features

- ✅ Custom VPC with public and private subnets across two Availability Zones (us-east-1a & us-east-1b)
- ✅ Internet Gateway and dual NAT Gateways (for high availability in private subnets)
- ✅ Route Tables with correct associations for each subnet
- ✅ Security Groups for:
  - Bastion Host (SSH only from your IP)
  - Load Balancer (HTTP/HTTPS from the internet)
  - EC2 Instances (access controlled by Bastion and Load Balancer)
  - RDS (MySQL access restricted to EC2 instances only)
- ✅ Remote backend using:
  - 🔐 S3 bucket with versioning for storing Terraform state
  - 🔐 DynamoDB table for state locking (prevents simultaneous `apply`)



## 🚀 Advanced Features

### 1️⃣ **Elastic Load Balancing (ALB)**
- Configured an **Application Load Balancer (ALB)** to distribute incoming HTTP traffic to the EC2 instances in private subnets.
- **User Data** on EC2 instances ensures they are configured to respond to HTTP requests (via Python HTTP server).
- Load balancer health checks monitor EC2 instances for availability and ensure traffic is only sent to healthy instances.

### 2️⃣ **Auto Scaling**
- Auto Scaling Group (ASG) is set up with **Launch Template** to manage EC2 instances in private subnets.
- EC2 instances automatically scale out or scale in based on CPU utilization.
- **CloudWatch Alarms** are configured to trigger scaling policies when the CPU usage exceeds 70% (scale-out) or drops below 30% (scale-in).

### 3️⃣ **CloudWatch Alarms and Scaling Policies**
- **High CPU Alarm**: Triggers a scale-out policy when CPU utilization exceeds 70% for a given period.
- **Low CPU Alarm**: Triggers a scale-in policy when CPU utilization drops below 30%.
- **Scaling Policies**: Automatically adds or removes EC2 instances based on the CloudWatch alarms, ensuring optimal resource utilization.

### 4️⃣ **Stateful Management with S3 & DynamoDB**
- Terraform uses a **remote backend** with **S3** to store state files, ensuring collaborative teams can work on the infrastructure safely.
- **DynamoDB** is used for **state locking** to prevent race conditions during Terraform apply operations.

### 5️⃣ **SSH Access**
- Access to EC2 instances is done through a **Bastion Host** (jump host) for security.
- The **SSH agent** is used to manage keys and simplify access to EC2 instances in private subnets.
- SSH access requires using a combination of Bastion Host access and the private EC2 instance’s IP.

### 6️⃣ **Database Connectivity**
- **RDS (MySQL)** is hosted in private subnets, with no public access.
- EC2 instances in private subnets can access the RDS instance securely.
- EC2 instances connect to RDS via **private IP** addresses for increased security.
```




## ⚙️ Prerequisites

- [Terraform CLI](https://www.terraform.io/downloads) ≥ 1.3
- AWS CLI configured with IAM credentials (`aws configure`)
- AWS account with permissions to create:
  - VPC, EC2, S3, DynamoDB, NAT Gateway, Internet Gateway, Elastic IPs, etc.

---

## 🔧 How to Use

### 1️⃣ Deploy the Remote Backend (only once)


cd terraform-backend-setup/
terraform init
terraform apply
This will create the S3 bucket and DynamoDB table used to store and lock the remote state.

2️⃣ Deploy the Main Infrastructure

cd ../terraform_vpc_project/
terraform init        # Connects to the remote backend
terraform plan        # Review the execution plan
terraform apply       # Deploy the infrastructure
💡 Configuration Notes
Update your public IP inside security.tf to restrict SSH access to the Bastion Host:


cidr_blocks = ["YOUR.PUBLIC.IP/32"]
You can use variables.tf and .tfvars files to manage different environments (e.g. dev, staging, prod).

All components are tagged for easy tracking in AWS.

📸 Architecture Diagram
The network architecture diagram is included in the repository as architecture-diagram.png. Please refer to it for a visual overview of the infrastructure.

📤 Outputs
You may optionally create an outputs.tf file to export useful data like:


output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
}
📜 License
This project is licensed under the MIT License. Feel free to use, modify, and share.

📬 Contact
If you have suggestions, questions, or issues, feel free to open an issue or pull request on the repository.
