# ElastiCache Redis Cluster on AWS

This project provisions an **Amazon ElastiCache for Redis 7.0** cluster inside an existing VPC using Terraform. It deploys both a single-node `aws_elasticache_cluster` (for plain-text internal access) and a hardened `aws_elasticache_replication_group` (with AUTH, in-transit and at-rest encryption) side-by-side, backed by a shared subnet group, a tuned parameter group, and a security group that allows Redis traffic only from the VPC CIDR, a designated admin IP, and other members of the same security group. A Python smoke-test script is included to validate the cluster with PING, SET/GET, LIST, HASH, and SET operations once the endpoint is reachable.

## Highlights

- **Redis 7.0** on `cache.t3.micro` nodes with `maxmemory-policy = allkeys-lru` (eviction-friendly cache behavior).
- **Two cluster shapes side-by-side**: a baseline cluster for internal use and a replication group with `auth_token`, `transit_encryption_enabled = true`, and `at_rest_encryption_enabled = true` for clients that need TLS + AUTH.
- **Network-tight security group**: ingress allowed only from the VPC CIDR (`10.50.0.0/16`), a single admin IP CIDR, and self (same SG) — all on port 6379.
- **Daily snapshots** with a one-day retention window and a dedicated maintenance window (Sunday 05:00–06:00 UTC, snapshot 04:00–05:00 UTC).
- **Python smoke-test harness** (`redis-test.py`) that exercises PING, strings, lists, hashes, sets, and cleans up — useful for post-deploy validation or CI health probes.

## Architecture

```
              +------------------------------+
              | Existing VPC <your-vpc-id>   |
              |                              |
              |  +-----------------------+   |
              |  | Subnet group (2 AZs)  |   |
              |  +-----------+-----------+   |
              |              |                |
              |  +-----------v-----------+   |
              |  | SG: redis-*           |<--+-- ingress 6379 from VPC CIDR
              |  | port 6379 only        |<--+-- ingress 6379 from admin IP /32
              |  +-----------+-----------+<--+-- ingress 6379 from self (SG)
              |              |                |
              |   +----------+----------+     |
              |   | ElastiCache cluster |     |
              |   | (plain, 1 node)     |     |
              |   +---------------------+     |
              |   | Replication group   |     |
              |   | (AUTH + TLS + KMS)  |     |
              |   +---------------------+     |
              +------------------------------+
```

All Redis resources share one parameter group (`redis-params`, family `redis7`) and one subnet group (`redis-subnet-group`). Outputs surface the primary cluster endpoint, port, and security group ID for consumption by dependent stacks.

## Tech stack

- **Terraform** 1.x, AWS provider `~> 5.0`
- **AWS services:** ElastiCache (cluster + replication group), ElastiCache Parameter Group, ElastiCache Subnet Group, VPC Security Groups
- **Other:** Python 3 with the `redis` client library for the smoke-test script

## Repository layout

```
REDIS-CLUSTER/
├── README.md
├── .gitignore
├── main.tf          # Provider, variables, SG, subnet group, parameter group, cluster, replication group, outputs
└── redis-test.py    # Connection smoke-test (PING, strings, list, hash, set, cleanup)
```

## How it works

1. `terraform apply` reads the VPC ID, subnet IDs, and admin IP variables (defaults provided, override per environment).
2. It creates a dedicated ElastiCache subnet group across two private subnets and a Redis-7 parameter group with LRU eviction.
3. A security group is created with three ingress rules on port 6379 — VPC CIDR, a single admin IP, and self-referential — plus all-egress.
4. It deploys two resources:
   - `aws_elasticache_cluster.redis` — a single-node cluster suitable for internal caching where TLS is not required.
   - `aws_elasticache_replication_group.redis` — a one-shard replication group with `auth_token`, `transit_encryption_enabled`, and `at_rest_encryption_enabled`, for clients that require encrypted + authenticated access.
5. Outputs print the primary endpoint and port. `redis-test.py` can then be pointed at that endpoint to run a full data-type smoke test and clean up after itself.

## Prerequisites

- Terraform >= 1.3
- AWS CLI configured (`aws configure`) with permissions for `elasticache:*`, `ec2:*SecurityGroup*`, `ec2:DescribeSubnets`, `ec2:DescribeVpcs`.
- An existing VPC with at least two private subnets in different AZs.
- Update the defaults in `main.tf` (`vpc_id`, `subnet_ids`, `stage_ip`, `prod_ip`, and the `cidr_blocks` on the security group ingress) before applying.
- For `redis-test.py`: Python 3.8+ and `pip install redis`.

## Deployment

```bash
terraform init
terraform plan
terraform apply
```

Then verify connectivity:

```bash
pip install redis
python redis-test.py   # edit the host to match the terraform output: redis_endpoint
```

## Teardown

```bash
terraform destroy
```

## Notes

- Demonstrates: secure ElastiCache deployment, dual-mode (plain + AUTH/TLS) presentation for heterogeneous clients, parameter-group tuning, restrictive SG ingress, snapshot + maintenance windows, and a real client-side validation loop.
- `auth_token` in `main.tf` is a placeholder — move it to a `tfvars` file or AWS Secrets Manager / SSM Parameter Store for real use.
- The `aws_elasticache_cluster` resource uses `num_cache_nodes = 1`; to move to a true multi-node setup, switch to the replication group only and increase `num_cache_clusters`.
- Hardcoded IPs (`13.113.17.177`, `18.183.194.177`, `170.64.231.76`) are placeholders from the original environment — replace with your own admin CIDRs before applying.
