ARG GO_VERSION=1.23
ARG UBUNTU_VERSION=22.04
ARG BUILDER_IMAGE="golang:${GO_VERSION}"
ARG RUNNER_IMAGE="ubuntu:${UBUNTU_VERSION}"

FROM ${BUILDER_IMAGE} AS base

ARG APP_NAME
ENV APP_NAME=${APP_NAME}

RUN echo "Build of $APP_NAME started"

RUN apt-get update -y && apt-get install --no-install-recommends -y ca-certificates unzip curl libc-bin libc6 \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app
COPY pkg pkg
COPY cmd cmd
COPY go.mod go.mod
COPY go.sum go.sum
COPY docker-entrypoint.sh /app/docker-entrypoint.sh

WORKDIR /app

FROM base AS dev

WORKDIR /tmp
RUN curl -sL https://github.com/google/protobuf/releases/download/v3.3.0/protoc-3.3.0-linux-x86_64.zip -o protoc && \
  unzip protoc && \
  mv bin/protoc /usr/local/bin/protoc

WORKDIR /app
RUN go install github.com/mgechev/revive@v1.7.0
RUN go install gotest.tools/gotestsum@v1.12.1
RUN go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.5.1
RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.36.10

CMD [ "/bin/bash",  "-c \"while sleep 1000; do :; done\"" ]

FROM base AS builder

RUN rm -rf build && go build -o build/${APP_NAME} cmd/server/main.go

FROM ${RUNNER_IMAGE} AS runner

# This is needed to connect the GitHub Container Registry package with our repository.
LABEL org.opencontainers.image.source https://github.com/semaphoreio/semaphore

RUN apt-get update -y && apt-get install --no-install-recommends -y ca-certificates \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

# We don't need Docker health checks, since these containers
# are intended to run in Kubernetes pods, which have probes.
HEALTHCHECK NONE

WORKDIR /app
RUN chown nobody /app

ARG APP_NAME
ENV APP_NAME=${APP_NAME}

# Only copy the binary and entrypoint from the build stage
COPY --from=builder --chown=nobody:root /app/build/${APP_NAME} /app/build/${APP_NAME}
COPY --from=builder --chown=nobody:root /app/docker-entrypoint.sh /app/docker-entrypoint.sh

USER nobody

CMD ["bash", "/app/docker-entrypoint.sh"]
