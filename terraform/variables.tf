provider "aws" {
  region = local.region
}

locals {
  region   = "us-east-1"
  key_pair = "scylla-jaeger"
  #  ami_id   = "ami-03c7d01cf4dedc891"
  ami_id = "ami-0fec2c2e2017f4e7b"

  node_exporter_image = "prom/node-exporter"
  scylladb_image      = "scylladb/scylla"

  ecs_cluster_name = "scylladb-ecs-cluster"

}