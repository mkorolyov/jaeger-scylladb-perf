provider "aws" {
  region = local.region
}

#terraform {
#  required_providers {
#    docker = {
#      source = "kreuzwerker/docker"
#    }
#  }
#}

locals {
  region           = "us-east-1"
  account_id       = "623708595330"
  ecs_cluster_name = "scylladb-ecs-cluster"

  scylladb_image  = "scylladb/scylla"
  cassandra_image = "cassandra:latest"
}