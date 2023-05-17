# Use a Maven base image
FROM maven:alpine as BUILD

# Set the working directory
WORKDIR /tests

# Copy the source code repository to the working directory
COPY jaeger-performance /tests

# Run the Maven tests
ENV TEST_CONFIG_FILE="test_config.yaml"
RUN mvn package -Dmaven.test.skip=true

FROM openjdk:alpine

# Set the working directory
WORKDIR /tests

COPY --from=BUILD /tests/target/performance-tests*-jar-with-dependencies.jar /tests/performance-tests.jar

CMD ["java", "-jar", "performance-tests.jar"]

