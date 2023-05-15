ACCOUNT ?= "unknown"
REGION ?= "us-east-1"
IMAGE_NAME ?= prometheus

docker_login:
	@ENDPOINT=${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com; \
	aws ecr get-login-password | docker login $${ENDPOINT} --username AWS --password-stdin

docker_update:
	docker buildx build --platform linux/amd64 -t ${IMAGE_NAME} ./${IMAGE_NAME}
	@ENDPOINT=${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com; \
	docker tag prometheus:latest $${ENDPOINT}/${IMAGE_NAME}:latest && \
	docker push $${ENDPOINT}/${IMAGE_NAME}:latest

ecs_update: docker_update
	aws ecs update-service --cluster scylladb-ecs-cluster --service ${IMAGE_NAME}_service --task-definition ${IMAGE_NAME}_task