# Jaeger collector load test

This is a load test for jaeger collector. It compares jaeger collector performance with cassandra and scylladb as storage backends.

Whole infrastructure is deployed on AWS using terraform. It creates a VPC, subnet, security group, ec2 instance and installs jaeger collector on it. It also creates prometheus server, db clusters and a load generator instance which runs the load test.

## Infra setup

All the infrastructure is deployed using terraform. It creates a VPC, subnet, security group, ec2 instances and runs required ecs services on them. 

### Prerequisites

Still short list of manual actions must be done before running terraform:

####  your_key_pair

Sign in to your AWS Management Console and navigate to the EC2 Dashboard. Under the "Network & Security" section in the left sidebar, click on "Key Pairs". If you don't have a key pair already, create a new one by clicking the "Create key pair" button. The name of the existing or newly created key pair is the value you need to use for key_pair that is used in terraform for ec2 setup. 

Update `key_pair` name with your created one in `terraform/ec2_instance/variables.tf` `key_pair` local variable.

#### AWS CLI

Setup aws cli with your credentials.

#### Terraform

install terraform cli

### Deploy

To deploy the infrastructure run:

```bash
terraform init -childdir=terraform
terraform apply -childdir=terraform
```

This will create all the required infrastructure on AWS except of prometheus server and load test docker image. We need to build them and push to the AWS by hands:

#### Prometheus

```bash
ACCOUNT=<your_aws_account_id> make docker login
ACCOUNT=<your_aws_account_id> IMAGE_NAME=prometheus make ecs_update
```

#### Load test

```bash
ACCOUNT=<your_aws_account_id> make docker login
ACCOUNT=<your_aws_account_id> IMAGE_NAME=load_tests make ecs_update
```

When images are pushed ecs agent on the nodes will pull them and run. Infra is ready, load tests is running with default settings and exists.

### Destroy

To cleanup all resources in AWS and destroy the infrastructure:

```bash
terraform destroy -childdir=terraform
```
