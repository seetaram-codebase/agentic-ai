# Terraform Infrastructure

## File Structure

```
terraform/
├── providers.tf          # Terraform & AWS provider config
├── variables.tf          # Input variables
├── outputs.tf            # Output values
│
├── s3.tf                 # S3 bucket for documents
├── sqs.tf                # SQS queues for processing
├── dynamodb.tf           # DynamoDB tables
├── lambda.tf             # Lambda function & IAM
├── ecr.tf                # ECR repository
├── ecs.tf                # ECS cluster, task, service
├── iam.tf                # IAM roles for ECS
├── vpc.tf                # VPC & security groups
│
└── environments/
    ├── dev.tfvars        # Development settings
    └── prod.tfvars       # Production settings
```

## Quick Start

### Initialize
```bash
cd infrastructure/terraform
terraform init
```

### Plan (Dev)
```bash
terraform plan -var-file=environments/dev.tfvars
```

### Apply (Dev)
```bash
terraform apply -var-file=environments/dev.tfvars
```

### Apply (Prod)
```bash
terraform apply -var-file=environments/prod.tfvars
```

### Destroy
```bash
terraform destroy -var-file=environments/dev.tfvars
```

## Resources Created

| File | Resources |
|------|-----------|
| `s3.tf` | S3 bucket, versioning, encryption, CORS, notifications |
| `sqs.tf` | Main queue, DLQ, S3 event policy |
| `dynamodb.tf` | Config table, Documents table |
| `lambda.tf` | Lambda function, IAM role, SQS trigger |
| `ecr.tf` | ECR repository, lifecycle policy |
| `ecs.tf` | Cluster, task definition, service |
| `iam.tf` | ECS task execution & task roles |
| `vpc.tf` | Default VPC data, security group |

## Environment Differences

| Setting | Dev | Prod |
|---------|-----|------|
| ECS CPU | 512 | 1024 |
| ECS Memory | 1024 MB | 2048 MB |
| ECS Tasks | 1 | 2 |
| Lambda Memory | 512 MB | 1024 MB |
| Log Retention | 7 days | 30 days |
