locals {
  region           = "us-east-1"
  key_pair         = "scylla-jaeger"
  ami_id           = "ami-0ebb9b1c37ef501ab" // ecs-optimized
  ecs_cluster_name = "scylladb-ecs-cluster"

  node_exporter_image = "prom/node-exporter"
}