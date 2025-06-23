ARG GO_VERSION=1.22
ARG ALPINE_VERSION=3.20.3
ARG BUILDER_IMAGE="golang:${GO_VERSION}"
ARG RUNNER_IMAGE="alpine:${ALPINE_VERSION}"

FROM ${BUILDER_IMAGE} AS base

ARG APP_NAME
ENV APP_NAME=${APP_NAME}

RUN echo "Build of $APP_NAME started"

RUN apt-get update -y && apt-get install --no-install-recommends -y ca-certificates unzip curl libc-bin libc6 \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /tmp
RUN curl -sL https://github.com/google/protobuf/releases/download/v3.3.0/protoc-3.3.0-linux-x86_64.zip -o protoc && \
  unzip protoc && \
  mv bin/protoc /usr/local/bin/protoc

WORKDIR /app

RUN go install github.com/mgechev/revive@v1.7.0
RUN go install gotest.tools/gotestsum@v1.12.1
RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
RUN go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest

FROM base AS dev

WORKDIR /app

COPY api api
COPY protos protos
COPY go.mod go.mod
COPY go.sum go.sum
COPY main.go main.go

RUN rm -rf build && CGO_ENABLED=0 go build -o build/server main.go

COPY test test
COPY scripts scripts
COPY lint.toml lint.toml

CMD [ "/bin/bash",  "-c \"while sleep 1000; do :; done\"" ]

FROM ${RUNNER_IMAGE} AS runner

# This is needed to connect the GitHub Container Registry package with our repository.
LABEL org.opencontainers.image.source https://github.com/semaphoreio/semaphore

RUN apk add --no-cache libc6-compat
HEALTHCHECK NONE

WORKDIR /app
RUN chown nobody /app
COPY --from=dev --chown=nobody:root /app/build/server /app/build/server

USER nobody

ENTRYPOINT ["/app/build/server"]
