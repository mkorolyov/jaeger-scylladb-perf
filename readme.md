#### took time: 
* 13min 19:00-19:13 for generation tf for prometheus
* 15min 13:30-13:45 generate scylladb tf 


#### todo in aws console
* your_key_pair: Sign in to your AWS Management Console and navigate to the EC2 Dashboard. Under the "Network & Security" section in the left sidebar, click on "Key Pairs". If you don't have a key pair already, create a new one by clicking the "Create key pair" button. The name of the existing or newly created key pair is the value you need to use for your_key_pair.
* your_ami_id: In the AWS Management Console, go to the EC2 Dashboard. Click on "Launch Instance" to view the list of available Amazon Machine Images (AMIs). Choose an appropriate Amazon Linux 2 AMI for your instance. You can find the AMI ID in the details section of the selected AMI. It should look like this: ami-0c55b159cbfafe1f0 (this is an example, the actual ID may be different). Use this AMI ID as the value for your_ami_id.
* your_vpc_id: In the AWS Management Console, navigate to the VPC Dashboard. Click on "Your VPCs" in the left sidebar to view a list of your VPCs. Choose the VPC where you want to launch your Prometheus server, and note down the VPC ID. It should look like this: vpc-0a1b2c3d4e5f6789a (this is an example, the actual ID may be different). Use this VPC ID as the value for your_vpc_id.
* your_subnet_id: In the AWS Management Console, go to the VPC Dashboard. Click on "Subnets" in the left sidebar to view a list of your subnets. Choose a subnet within the VPC that you selected earlier, and note down the subnet ID. It should look like this: subnet-0a1b2c3d4e5f6789a (this is an example, the actual ID may be different). Use this subnet ID as the value for your_subnet_id.
