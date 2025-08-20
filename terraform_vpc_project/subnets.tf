# Public Subnet in us-east-1a
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "Public Subnet 1"
  }
}

# Public Subnet in us-east-1b
resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "Public Subnet 2"
  }
}

# Private Subnet in us-east-1a
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "Private Subnet 1"
  }
}

# Private Subnet in us-east-1b
resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "Private Subnet 2"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "MyInternetGateway"
  }
}

# Creation of the public Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "PublicRouteTable"
  }
}

# Route Table association to the public subnet in AZ1
resource "aws_route_table_association" "public_rt_association_1" {
  subnet_id      = aws_subnet.public_subnet_1.id  # AZ 1
  route_table_id = aws_route_table.public_rt.id
}

# Route Table association to the public subnet in AZ2
resource "aws_route_table_association" "public_rt_association_2" {
  subnet_id      = aws_subnet.public_subnet_2.id  # AZ 2
  route_table_id = aws_route_table.public_rt.id
}

# Elastic IP for NAT Gateway in AZ1 
resource "aws_eip" "nat_az1" {
  
}

# NAT Gateway in AZ1
resource "aws_nat_gateway" "nat_az1" {
  allocation_id = aws_eip.nat_az1.id  # Link the NAT Gateway to the Elastic IP
  subnet_id     = aws_subnet.public_subnet_1.id  # Place the NAT Gateway in a public subnet in AZ1
  tags = {
    Name = "NAT-Gateway-AZ1"  # Tag to identify the NAT Gateway
  }
}

# Elastic IP for NAT Gateway in AZ2
resource "aws_eip" "nat_az2" {
  
}

# NAT Gateway in AZ2
resource "aws_nat_gateway" "nat_az2" {
  allocation_id = aws_eip.nat_az2.id  # Link the NAT Gateway to the Elastic IP
  subnet_id     = aws_subnet.public_subnet_2.id  # Place the NAT Gateway in a public subnet in AZ2
  tags = {
    Name = "NAT-Gateway-AZ2"  # Tag to identify the NAT Gateway
  }
}

# Route Table for Private Subnet in AZ1
resource "aws_route_table" "private_rt_az1" {
  vpc_id = aws_vpc.main.id  # Specify the VPC where the route table is located

  route {
    cidr_block = "0.0.0.0/0"  # Route for internet traffic
    gateway_id = aws_nat_gateway.nat_az1.id  # Use NAT Gateway AZ1 to reach the internet
  }

  tags = {
    Name = "PrivateRouteTable-AZ1"  # Tag for the route table
  }
}

# Route Table association for Private Subnet in AZ1
resource "aws_route_table_association" "private_rt_association_az1" {
  subnet_id      = aws_subnet.private_subnet_1.id  # Associate the route table with the private subnet in AZ1
  route_table_id = aws_route_table.private_rt_az1.id  # Associate the route table defined earlier
}

# Route Table for Private Subnet in AZ2
resource "aws_route_table" "private_rt_az2" {
  vpc_id = aws_vpc.main.id  # Specify the VPC where the route table is located

  route {
    cidr_block = "0.0.0.0/0"  # Route for internet traffic
    gateway_id = aws_nat_gateway.nat_az2.id  # Use NAT Gateway AZ2 to reach the internet
  }

  tags = {
    Name = "PrivateRouteTable-AZ2"  # Tag for the route table
  }
}

# Route Table association for Private Subnet in AZ2
resource "aws_route_table_association" "private_rt_association_az2" {
  subnet_id      = aws_subnet.private_subnet_2.id  # Associate the route table with the private subnet in AZ2
  route_table_id = aws_route_table.private_rt_az2.id  # Associate the route table defined earlier
}
