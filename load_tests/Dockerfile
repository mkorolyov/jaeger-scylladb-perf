#Build stage

FROM golang:1.20.3-alpine3.16 as BuildStage

WORKDIR /app

COPY . .

RUN go build -v -o bin/binary main.go

# Deploy stage

FROM alpine:3.16

COPY --from=BuildStage /app/bin/binary /app/binary

EXPOSE 9101

ENTRYPOINT "/app" "-addr" "${addr_env}"