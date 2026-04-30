# Project 34: ElastiCache Redis on AWS with Terraform

Terraform module that provisions an Amazon ElastiCache for Redis 7.0 deployment inside an existing VPC. The module deploys two cluster shapes side by side: a plain single-node cluster for internal callers, and a replication group with AUTH plus in-transit and at-rest encryption for clients that require TLS. Both share a subnet group spanning two AZs, a tuned parameter group, and a security group restricted to the VPC CIDR, designated admin IPs, and self-referential traffic.

A Python smoke-test script is included to validate the deployment with PING, strings, lists, hashes, and sets after the endpoints become reachable.

## Architecture

```
Existing VPC
   |
   +-- Subnet group (2 private subnets across 2 AZs)
   |
   +-- Security group (port 6379 only)
   |     |
   |     +-- ingress from VPC CIDR
   |     +-- ingress from admin IP /32
   |     +-- ingress from self (same SG)
   |
   +-- ElastiCache cluster        (plain, 1 node, cache.t3.micro)
   +-- ElastiCache replication    (AUTH + TLS in-transit + at-rest encryption)
       group                       1 shard, cache.t3.micro
```

Both Redis resources share one parameter group (`redis-params`, family `redis7`) and one subnet group (`redis-subnet-group`).

## What It Provisions

- ElastiCache subnet group spanning two private subnets
- Parameter group (`redis7` family) with `maxmemory-policy = allkeys-lru`
- Security group with three ingress rules on port 6379: VPC CIDR, admin IP, and self-referential
- `aws_elasticache_cluster` — single-node Redis 7.0 on `cache.t3.micro`, no encryption, no auth
- `aws_elasticache_replication_group` — single-shard replication group on `cache.t3.micro` with `auth_token`, `transit_encryption_enabled = true`, and `at_rest_encryption_enabled = true`
- Daily snapshots with one-day retention
- Maintenance window: Sunday 05:00–06:00 UTC
- Snapshot window: 04:00–05:00 UTC
- Outputs: primary cluster endpoint, port, security group ID

## Smoke-Test Script

`redis-test.py` validates a deployed endpoint by exercising:

- `PING`
- String SET/GET
- List operations (`LPUSH`, `LRANGE`)
- Hash operations (`HSET`, `HGETALL`)
- Set operations (`SADD`, `SMEMBERS`)
- Cleanup of all test keys

Useful as a post-deploy smoke test or a CI health probe.

## Stack

Terraform 1.x · AWS provider ~> 5.0 · ElastiCache Redis 7.0 · VPC · Security Groups · Python 3 · `redis` client library

## Repository Layout

```
elasticache-redis-terraform/
├── main.tf            # Provider, variables, SG, subnet group, parameter group, cluster, replication group, outputs
├── redis-test.py      # Smoke test (PING, strings, lists, hashes, sets, cleanup)
├── .gitignore
└── README.md
```

## Prerequisites

- Terraform >= 1.3
- AWS CLI configured with permissions for `elasticache:*`, `ec2:*SecurityGroup*`, `ec2:DescribeSubnets`, `ec2:DescribeVpcs`
- An existing VPC with at least two private subnets in different AZs
- Python 3.8+ with `pip install redis` (for the smoke test only)

## Deployment

Update the variables in `main.tf` (`vpc_id`, `subnet_ids`, admin IP CIDRs, and the security group `cidr_blocks`) before applying.

```bash
terraform init
terraform plan
terraform apply
```

Verify connectivity:

```bash
pip install redis
python redis-test.py    # update the host to match the terraform output: redis_endpoint
```

## Teardown

```bash
terraform destroy
```

## Notes

- **`auth_token` is a placeholder in `main.tf`.** Move it to a gitignored `terraform.tfvars`, the `TF_VAR_auth_token` environment variable, or AWS Secrets Manager / SSM Parameter Store before applying. Never commit a real auth token.
- **Hardcoded admin IPs in `main.tf`** are placeholders from a prior environment. Replace with the IP CIDRs allowed to reach Redis from outside the VPC, or remove that ingress rule entirely if no external access is required.
- **Two cluster shapes side by side** is unusual. Most deployments use one or the other: a plain cluster for internal-only caching, or an encrypted replication group for everything. The dual-mode setup here suits a transitional state where some clients support TLS and AUTH and some do not. For a unified production deployment, consolidate to the replication group only.
- **`num_cache_nodes = 1`** on the plain cluster means a single point of failure. For HA, switch entirely to the replication group and increase `num_cache_clusters` to add replicas.
- **Snapshot retention is one day.** Extend `snapshot_retention_limit` for longer recovery windows if your data warrants it.
- **No automatic failover on the replication group** unless `automatic_failover_enabled = true` is set and the cluster has at least one replica. Verify the configuration matches your availability requirements.
