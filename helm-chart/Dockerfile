FROM alpine:3.19 AS base

# Install required packages
RUN apk add --no-cache \
    bash \
    git \
    jq \
    make \
    yq \
    curl \
    openssl \
    helm

FROM base AS helm

WORKDIR /workspace

# Create directory structure
RUN mkdir -p /workspace/helm-chart

# Set the working directory to helm-chart
WORKDIR /workspace/helm-chart

# We'll mount the current directory here during runtime
ENTRYPOINT ["/bin/bash"]
