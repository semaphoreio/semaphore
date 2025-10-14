ARG GO_VERSION=1.23.8
ARG ALPINE_VERSION=3.20

FROM golang:${GO_VERSION}-alpine${ALPINE_VERSION} AS builder
WORKDIR /app

# Allow matching version of Go tools inside container.
ENV CGO_ENABLED=0 \
    GO111MODULE=on \
    GOOS=linux \
    GOARCH=amd64

# Copy module manifests and download dependencies.
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go mod download

# Copy source code.
COPY cmd ./cmd
COPY pkg ./pkg

# Build the server binary.
RUN --mount=type=cache,target=/root/.cache/go-build \
    go build -o /bin/mcp_server ./cmd/mcp_server

FROM alpine:${ALPINE_VERSION}
RUN adduser -D -H -s /sbin/nologin appuser
USER appuser
WORKDIR /app

COPY --from=builder /bin/mcp_server /usr/local/bin/mcp_server

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/mcp_server"]
CMD ["-http", ":8080"]
