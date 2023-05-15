# Use a Maven base image
FROM maven:3.6.3-openjdk-11-slim

# Set the working directory
WORKDIR /tests

# Copy the source code repository to the working directory
COPY jaeger-performance /tests

# Run the Maven tests
ENV TEST_CONFIG_FILE="test_config.yaml"
RUN mvn test