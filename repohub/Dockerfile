ARG GO_VERSION=1.23
ARG UBUNTU_VERSION=22.04
ARG BUILDER_IMAGE="golang:${GO_VERSION}"
ARG RUNNER_IMAGE="ubuntu:${UBUNTU_VERSION}"

FROM ${BUILDER_IMAGE} AS base

ARG APP_NAME
ENV APP_NAME=${APP_NAME}

RUN echo "Build of $APP_NAME started"

RUN apt-get update -y && apt-get install --no-install-recommends -y \
    ca-certificates unzip curl cmake pkg-config libssl-dev libssh2-1-dev zlib1g-dev postgresql-client \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set working directory for downloading and building libgit2
WORKDIR /tmp/libgit2-src

# Download and extract libgit2 1.5 source code
RUN curl -LO https://github.com/libgit2/libgit2/archive/refs/tags/v1.5.0.tar.gz && \
    tar -xzf v1.5.0.tar.gz --strip-components=1 && rm -f v1.5.0.tar.gz

# Set working directory for building libgit2
WORKDIR /tmp/libgit2-src/build

# Build and install libgit2
RUN cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local && \
    cmake --build . && \
    cmake --install .

# Clean up temporary files
WORKDIR /
RUN rm -rf /tmp/libgit2-src

# Set LD_LIBRARY_PATH
# Make ensure that the dynamic linker looks for shared libraries in /usr/local/lib,
# which is where libgit2 is installed.
ENV LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

WORKDIR /app
COPY pkg pkg
COPY cmd cmd
COPY go.mod go.mod
COPY go.sum go.sum
COPY git-ask-pass.sh git-ask-pass.sh
COPY docker-entrypoint.sh /app/docker-entrypoint.sh

WORKDIR /app

FROM base AS dev

WORKDIR /tmp
RUN curl -sL https://github.com/google/protobuf/releases/download/v3.20.0/protoc-3.20.0-linux-x86_64.zip -o protoc && \
    unzip protoc && \
    mv bin/protoc /usr/local/bin/protoc

RUN curl -sL https://github.com/golang-migrate/migrate/releases/download/v4.18.1/migrate.linux-amd64.tar.gz | tar xvz && \
    mv /tmp/migrate /usr/bin/migrate && \
    chmod +x /usr/bin/migrate

WORKDIR /app
RUN go install github.com/mgechev/revive@v1.4.0
RUN go install gotest.tools/gotestsum@v1.12.1
RUN go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.3.0
RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.36.8

CMD [ "/bin/bash",  "-c \"while sleep 1000; do :; done\"" ]

FROM base AS builder

RUN rm -rf build && go build -o build/${APP_NAME} cmd/server/main.go

FROM ${RUNNER_IMAGE} AS runner

# This is needed to connect the GitHub Container Registry package with our repository.
LABEL org.opencontainers.image.source https://github.com/semaphoreio/semaphore

RUN apt-get update -y && apt-get install --no-install-recommends -y git ca-certificates sudo \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Add 'nobody' to the sudo group and configure sudo privileges
# We will drop it later in the pod after changing the ownership of /var/repos
RUN echo 'nobody ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
    && usermod -aG sudo nobody

# We don't need Docker health checks, since these containers
# are intended to run in Kubernetes pods, which have probes.
HEALTHCHECK NONE

WORKDIR /app
RUN chown nobody /app

ARG APP_NAME
ENV APP_NAME=${APP_NAME}

# Copy compiled libgit2 from base stage
COPY --from=base /usr/local/lib/libgit2* /usr/local/lib/
COPY --from=base /usr/local/include/git2 /usr/local/include/git2

# Set LD_LIBRARY_PATH
# Make ensure that the dynamic linker looks for shared libraries in /usr/local/lib,
# which is where libgit2 is installed.
ENV LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

# Only copy the binary and entrypoint from the build stage
COPY --from=builder --chown=nobody:root /app/build/${APP_NAME} /app/build/${APP_NAME}
COPY --from=builder --chown=nobody:root /app/docker-entrypoint.sh /app/docker-entrypoint.sh

# Copy and set permissions for git-ask-pass.sh script
COPY --from=builder --chown=nobody:root /app/git-ask-pass.sh /app/git-ask-pass.sh
RUN chmod +x /app/git-ask-pass.sh
ENV GIT_ASKPASS=/app/git-ask-pass.sh

USER nobody

CMD ["bash", "/app/docker-entrypoint.sh"]
