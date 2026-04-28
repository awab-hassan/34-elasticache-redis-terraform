# Create subnet group
resource "aws_elasticache_subnet_group" "redis" {
  name        = "redis-subnet-group"
  description = "Subnet group for Redis cluster"
  subnet_ids  = var.subnet_ids
}

# Create parameter group
resource "aws_elasticache_parameter_group" "redis" {
  family      = "redis7"
  name        = "redis-params"
  description = "Redis parameter group"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }
}

# Create security group
resource "aws_security_group" "redis" {
  name_prefix = "redis-security-group-"
  description = "Security group for Redis cluster"
  vpc_id      = var.vpc_id

  # Allow access from VPC CIDR
  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["10.50.0.0/16"]  # Adjust this to match your VPC CIDR
    description = "Allow Redis access from VPC"
  }


  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["xx.xxx.xx.xx/32"]  # Adjust this to match your VPC CIDR
    description = "Allow Redis access from VPC"
  }

  # Allow access from the same security group
  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    self            = true
    description     = "Allow Redis access within security group"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "redis-security-group"
    Environment = "shared"
    Terraform   = "true"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Create Redis cluster
resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "redis-cluster"
  engine              = "redis"
  engine_version      = "7.0"
  node_type           = "cache.t3.micro"
  num_cache_nodes     = 1
  parameter_group_name = aws_elasticache_parameter_group.redis.name
  port                = 6379

  security_group_ids = [aws_security_group.redis.id]
  subnet_group_name = aws_elasticache_subnet_group.redis.name

  # Maintenance settings
  maintenance_window = "sun:05:00-sun:06:00"
  snapshot_window = "04:00-05:00"
  snapshot_retention_limit = 1
  auto_minor_version_upgrade = true

  # Add these settings for better connectivity
  apply_immediately = true
  notification_topic_arn = null  # Optional: Add SNS topic ARN for notifications

  tags = {
    Name        = "redis-cluster"
    Environment = "shared"
    Terraform   = "true"
  }
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = "redis-cluster-rg"
  description                = "Redis cluster with encryption and authentication"
  engine                     = "redis"
  engine_version             = "7.0"
  node_type                  = "cache.t3.micro"
  num_cache_clusters         = 1
  parameter_group_name       = aws_elasticache_parameter_group.redis.name
  port                       = 6379
  
  # Authentication and encryption
  auth_token                  = "XXXXXXXXXXXXXXX"  # Your 16+ char password
  transit_encryption_enabled  = true
  at_rest_encryption_enabled  = true
  
  security_group_ids         = [aws_security_group.redis.id]
  subnet_group_name          = aws_elasticache_subnet_group.redis.name

  # Maintenance settings
  maintenance_window         = "sun:05:00-sun:06:00"
  snapshot_window            = "04:00-05:00"
  snapshot_retention_limit   = 1
  auto_minor_version_upgrade = true
  apply_immediately          = true

  tags = {
    Name        = "redis-cluster"
    Environment = "shared"
    Terraform   = "true"
  }
}
