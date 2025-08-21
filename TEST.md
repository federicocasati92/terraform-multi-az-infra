# Tests and Validation

This section documents the validation steps I performed to test the AWS VPC infrastructure deployed with Terraform.

### 1️⃣ SSH Access via Bastion Host (Jump Host)

* Ensure your private key is loaded into your SSH agent to simplify SSH access:

```bash
ssh-add ~/.ssh/my-ec2-key
```

* Your SSH config (`~/.ssh/config`) should include entries for bastion and private EC2 hosts, for example:

```ssh-config
Host bastion
  HostName <bastion_public_ip>
  User ec2-user
  IdentityFile ~/.ssh/my-ec2-key
  ForwardAgent yes

Host ec2-private-1
  HostName <private_ec2_private_ip_1>
  User ec2-user
  ProxyJump bastion

Host ec2-private-2
  HostName <private_ec2_private_ip_2>
  User ec2-user
  ProxyJump bastion
```

* You can then connect simply using:

```bash
ssh bastion
ssh ec2-private-1
ssh ec2-private-2
```

---

### 2️⃣ Obtain IP Addresses of Bastion and Private EC2 Instances in Autoscaling Group (ASG)

* Get the public IP of the bastion host (via AWS CLI or console):

```bash
aws ec2 describe-instances --filters "Name=tag:Name,Values=BastionHost" \
  --query "Reservations[0].Instances[0].PublicIpAddress" --output text
```

* Get private IPs of EC2 instances inside the ASG:

```bash
ASG_NAME="your-asg-name"

INSTANCE_IDS=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $ASG_NAME \
  --query "AutoScalingGroups[0].Instances[].InstanceId" \
  --output text)

aws ec2 describe-instances \
  --instance-ids $INSTANCE_IDS \
  --query "Reservations[].Instances[].PrivateIpAddress" \
  --output text
```

### 3️⃣ Network Connectivity Tests

* From private EC2 instances, verify internet connectivity by pinging external hosts:

```bash
ping -c 4 google.com
```

---

### 4️⃣ Load Balancer and Application Response

* EC2 instances launched by the ASG run a simple Python HTTP server via user data that returns the instance hostname.

* You can verify the load balancer forwards traffic and distributes requests to healthy instances by curling the ALB DNS name:

```bash
curl http://<your-alb-dns-name>/
```

* The response should alternate between hostnames of the two EC2 instances behind the load balancer, confirming healthy targets and correct load balancing.

---

### 5️⃣ Autoscaling and CloudWatch Alarms

* To test autoscaling, install a CPU stress tool on the instances (e.g., the private EC2 instances or via user data):

```bash
sudo amazon-linux-extras install epel -y
sudo yum install stress -y
```

* Run stress to raise CPU utilization above the CloudWatch alarm threshold:

```bash
stress --cpu 2 --timeout 300
```

* This should trigger CloudWatch alarm (`CPUUtilization > 70%`), invoking the scale-out policy which adds a new EC2 instance to the ASG.

* You can verify scale-out from the AWS Console or with:

```bash
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $ASG_NAME \
  --query "AutoScalingGroups[0].Instances[].InstanceId" --output text
```

* After CPU usage decreases below the threshold, scale-in policy will remove instances accordingly.

---

### 6️⃣ Access to RDS from Private EC2 Instances

* From private EC2 instances, install MySQL client:

```bash
sudo yum install -y mysql
```

* Connect to the RDS database using:

```bash
mysql -h <rds_endpoint> -u admin -p
```

* This confirms proper security group rules and private network connectivity.

---

### 7️⃣ Important Notes

* The SSH private key must be manually added to the SSH agent at the start of your terminal session using:

```bash
ssh-add ~/.ssh/my-ec2-key
```

* The SSH config file simplifies connecting through the bastion host.

* The Python HTTP server in the user data script enables testing of ALB routing.
