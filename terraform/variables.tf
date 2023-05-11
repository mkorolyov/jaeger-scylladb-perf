provider "aws" {
  region = local.region
}

terraform {
  required_providers {
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

#provider "aws-ecr" {
#  region = local.region
#}

locals {
  region   = "us-east-1"
  account_id = "623708595330"
  key_pair = "scylla-jaeger"
  ami_id = "ami-0ebb9b1c37ef501ab" // ecs-optimized

  node_exporter_image = "prom/node-exporter"
  scylladb_image      = "scylladb/scylla"
}