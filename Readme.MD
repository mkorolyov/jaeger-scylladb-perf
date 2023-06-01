## Jaeger Collector Load Test

This document presents a comprehensive load test for the Jaeger Collector, focusing on comparing its performance when utilizing Cassandra and ScyllaDB as storage backends.

The entire infrastructure for this load test is deployed on Amazon Web Services (AWS) using Terraform. The deployment process includes setting up a Virtual Private Cloud (VPC), a subnet, a security group, and an EC2 instance. On the EC2 instance, the Jaeger Collector is installed, enabling the collection and processing of distributed traces. Additionally, a Prometheus server, database clusters, and a load generator instance are created to facilitate the load testing procedure.

Load testing is a crucial aspect of assessing the performance and scalability of any system. By subjecting the Jaeger Collector to various levels of simulated traffic, we can analyze its behavior and identify potential bottlenecks or areas for optimization. This test specifically focuses on comparing the performance of the Jaeger Collector when using Cassandra and ScyllaDB as storage backends.

Cassandra is a highly scalable and distributed NoSQL database known for its fault tolerance and ability to handle large amounts of data. On the other hand, ScyllaDB is a drop-in replacement for Cassandra, designed to provide improved performance and scalability by leveraging a shared-nothing architecture and utilizing a high-performance C++ engine.

During the load test, we will generate synthetic traces using the load generator instance. These traces will be ingested by the Jaeger Collector, which will store them in either Cassandra or ScyllaDB, depending on the configuration.

In the following sections, we will outline the step-by-step process of deploying the infrastructure, configuring the Jaeger Collector, executing the load test, and analyzing the obtained results. Stay tuned for an in-depth exploration of Jaeger Collector's performance and its compatibility with Cassandra and ScyllaDB as storage backends.

## Infrastructure Deployment with Terraform

The infrastructure for this load test is deployed using Terraform, ensuring a reproducible and scalable setup. The deployment process involves creating essential AWS resources such as a Virtual Private Cloud (VPC), subnet, security group, and EC2 instances. Additionally, required ECS services are also launched on the EC2 instances to support the load testing activities.

### Prerequisites

Before running Terraform, ensure that the following manual actions are completed:

1. **Key Pair Setup** : Sign in to the AWS Management Console and navigate to the EC2 Dashboard. Under the "Network & Security" section in the left sidebar, click on "Key Pairs". If you don't have a key pair already, create a new one by clicking the "Create key pair" button. The name of the existing or newly created key pair is the value you need to use for the `key_pair` variable in the `terraform/ec2\_instance/variables.tf` file.
2. **AWS CLI Configuration** : Set up the AWS CLI with your credentials to enable programmatic access to your AWS resources.
3. **Terraform Installation** : Install the Terraform CLI on your local machine to manage the infrastructure deployment process.

### Deployment

To deploy the infrastructure, follow these steps:

1. 1. Initialize Terraform in the `terraform` subdirectory:

terraform init -chdir=terraform

1. Apply the Terraform configuration to create the required infrastructure:

terraform apply -childdir=terraform

Executing these commands will provision all the necessary resources on AWS, except for the Prometheus server and the load test Docker image. We need to manually build and push them to AWS.

### Building and Pushing Docker Images

Before proceeding with building and pushing the Docker images, make sure you have logged in to the Docker registry with your AWS credentials.

1. **Prometheus** : Run the following commands, replacing \<your\_aws\_account\_id\> with your actual AWS account ID:

ACCOUNT=\<your\_aws\_account\_id\> make docker login

ACCOUNT=\<your\_aws\_account\_id\> IMAGE\_NAME=prometheus make ecs\_update

The Prometheus Docker image will be built and pushed to AWS, allowing the ECS agent on the nodes to pull and run the image. Also ECS service will be force updated which could be treated as excess as agent will pull the image anyway sooner or later but we will speed this up.

2. **Load Test** : Similarly, execute the following command to build and push the load test Docker image(we are dropping here docker login as already did it):

ACCOUNT=\<your\_aws\_account\_id\> IMAGE\_NAME=load\_tests make ecs\_update

Once the images are successfully pushed, the ECS agent on the nodes will pull them and run which initiates the load test. At this point, the infrastructure is ready, and the load test is running with default settings.

### Infrastructure Cleanup

To remove all resources and clean up the infrastructure from AWS, execute the following Terraform command:

terraform destroy -chdir=terraform

This command will effectively delete all the provisioned resources, ensuring that you are not billed for any unused services.

Make sure to follow these instructions carefully to ensure a smooth deployment and cleanup process for the load test infrastructure.

## Load Test Design

The load test for the Jaeger Collector involves configuring various environment variables to define the parameters of the test. These variables determine the behavior of the load generator and control the characteristics of the generated traces. Let's explore each of these environment variables:

1. **CONCURRENCY** : (Default = 10) This variable specifies the number of coroutines used to generate traces concurrently during the load test. The higher the concurrency value, the greater the number of traces generated simultaneously. Increasing the concurrency can help simulate a higher volume of concurrent requests to assess the system's scalability and response under heavy load.

2. **SPANS\_COUNT** : (Default = 10) The SPANS\_COUNT variable determines the number of child spans created per trace. A span represents a unit of work or activity within a trace. By defining the number of spans per trace, you can simulate different levels of complexity in the distributed traces generated during the load test. Increasing the spans count can help evaluate the system's performance in handling more intricate trace structures.

3. **TAGS\_COUNT** : (default = 10) This variable controls the number of tags associated with each individual span within a trace. Tags provide additional contextual information about a span, such as metadata or labels. By adjusting the tags count, you can simulate scenarios where each span carries varying amounts of metadata. This helps assess the system's ability to process and store a larger volume of tag data associated with the distributed traces.

4. **DURATION\_S** : (default = 60) The DURATION\_S variable sets the duration in seconds for which the load test will run. It defines the total time during which traces will be continuously generated and ingested by the Jaeger Collector. By specifying the duration, you can control the duration of the load test and observe how the system's performance and resource utilization evolve over time.

By adjusting these environment variables, you can tailor the load test to mimic different scenarios and workloads, allowing for a comprehensive evaluation of the Jaeger Collector's performance under varying conditions. It is recommended to carefully choose appropriate values for these variables based on your specific testing objectives and the expected production workload characteristics.

During the load test, the load generator instance will utilize the defined values for these variables to generate and send traces to the Jaeger Collector. The collector will then process and store the traces according to the configured storage backend (Cassandra or ScyllaDB). The performance of the Jaeger Collector, including metrics such as throughput, latency, and resource utilization, can be monitored and analyzed to gain insights into its behavior and scalability under different load test scenarios.

## Performance Metrics

To evaluate the performance of the Jaeger Collector and compare the efficiency of different storage backends (ScyllaDB and Cassandra), we will primarily focus on the total spans count processed by the Jaeger Collector during the load tests.

Since we don't have access to the OpenTracing SDK for measuring latency between the load test generator and the Jaeger Collector directly, we will rely on the spans count as an indicator of the Jaeger Collector's capability to handle the incoming traces.

For accurate comparison, we will conduct two separate load tests using the same environment variable values, hardware configuration, and Jaeger Collector settings. The only difference will be the choice of the storage backend: one test will use ScyllaDB, while the other will use Cassandra.

By observing the spans count in each load test, we can assess the ability of the Jaeger Collector to process and store distributed traces efficiently on each storage backend. A higher spans count indicates that the Jaeger Collector successfully handled a larger volume of traces, reflecting better performance and scalability.

Comparing the spans count between the load tests will provide valuable insights into the relative performance of ScyllaDB and Cassandra as storage backends for the Jaeger Collector. The test results will allow us to determine which backend exhibits better trace processing capabilities and can handle a greater number of spans under similar load conditions.

By controlling the variables other than the storage backend, such as the load test configuration, hardware specifications, and Jaeger Collector setup, we can isolate the impact of the storage backend itself on the Jaeger Collector's performance. This controlled experiment approach ensures a fair and meaningful comparison between the two storage options.

## Load Test Execution

For the load test execution, we will utilize the following environment variable values:

- CONCURRENCY: 10

- SPANS\_COUNT: 10

- TAGS\_COUNT: 10

- DURATION\_S: 60 seconds

These values are set in the Terraform configuration, specifically in the load test service container definition. They determine the parameters and characteristics of the load generated during the test.

The Jaeger Collector, Prometheus, and the load test itself will be deployed on EC2 instances of the t2.micro type. These instances offer 1 CPU and 1GB RAM. The database cluster, consisting of three nodes, will be deployed on t2.medium instances. Each t2.medium instance provides 2 CPUs and 4GB RAM. This hardware configuration allows for a sufficient level of resources to support the load test activities.

All services, including the Jaeger Collector, Prometheus, and the load test, are packaged into Docker images and deployed to the respective hosts as ECS services. Additionally, each host also runs the Prometheus Node Exporter, which collects host-level metrics such as CPU usage, RAM utilization, disk I/O, and network I/O.

By deploying the services as ECS services and utilizing Docker containers, we ensure consistency and ease of deployment across the infrastructure. The load test environment is designed to be scalable, allowing for the efficient execution of the load test with the specified environment variable values.

During the load test execution, the load generator will generate traces based on the defined environment variables. These traces will be sent to the Jaeger Collector, which will process and store them based on the selected storage backend (ScyllaDB or Cassandra).

The Prometheus server will monitor the performance metrics of the load test environment, including the resource utilization of the EC2 instances, container-level metrics, and any custom metrics exposed by the load test itself.

By collecting and analyzing these metrics, we can gain insights into the performance, scalability, and resource utilization of the Jaeger Collector and the overall load test infrastructure. These metrics will provide valuable information for evaluating the efficiency and capacity of the system under the specified load and configuration.

Throughout the load test execution, it is recommended to monitor the Prometheus metrics to ensure the stability and health of the environment. This monitoring approach enables real-time visibility into the system's behavior and performance during the load test, facilitating prompt identification of any potential issues or bottlenecks.

Overall, the load test execution is designed to be straightforward and reliable, allowing for the evaluation of the Jaeger Collector's performance under the specified load conditions and infrastructure setup.

## Results and Analysis

During the load test, ScyllaDB successfully ran three nodes on the same host, with each node allocated 1GB of RAM and 512 CPU credits. The Jaeger Collector, utilizing ScyllaDB as the backend storage, managed to collect approximately 120,000 spans within a 60-second duration. This translates to an average rate of around 2,000 spans per second.

On the other hand, Cassandra was only able to run two nodes on the same host, with each node allocated 1.5GB of RAM and 512 CPU credits. With Cassandra as the backend storage, the Jaeger Collector was able to collect approximately 61,000 spans during the same 60-second duration. This corresponds to an average rate of close to 1,000 spans per second.

Analysis:

1. **ScyllaDB Performance** : ScyllaDB demonstrated better scalability and resource utilization compared to Cassandra in this specific load test scenario. Despite having fewer resources allocated to each node, ScyllaDB was able to handle a significantly higher number of spans per second, indicating its superior performance in processing and storing distributed traces.

2. **Cassandra Limitations** : The limited capacity of Cassandra to run only two nodes on the same host, despite having slightly higher resource allocations per node, resulted in a lower span collection rate. This suggests that Cassandra may have higher resource requirements or limitations that impacted its ability to handle a larger workload in this load test.

## Conclusions

Based on the results and analysis, it can be concluded that ScyllaDB outperformed Cassandra as a storage backend for the Jaeger Collector in terms of span collection rate. ScyllaDB demonstrated better scalability and efficiency, enabling the Jaeger Collector to handle a larger number of spans per second compared to Cassandra.