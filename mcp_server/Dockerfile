ARG GO_VERSION=1.25.2
ARG ALPINE_VERSION=3.22

FROM golang:${GO_VERSION}-alpine${ALPINE_VERSION} AS base
ARG APP_NAME
ARG BUILD_ENV
WORKDIR /app

ENV CGO_ENABLED=0 \
    GO111MODULE=on \
    GOOS=linux \
    GOARCH=amd64

COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go mod download

COPY cmd ./cmd
COPY pkg ./pkg
COPY test ./test

FROM base AS dev
RUN --mount=type=cache,target=/root/.cache/go-build \
    go build ./cmd/mcp_server
CMD ["sh", "-c", "while sleep 1000; do :; done"]

FROM base AS builder
RUN --mount=type=cache,target=/root/.cache/go-build \
    go build -o /tmp/mcp_server ./cmd/mcp_server

FROM alpine:${ALPINE_VERSION} AS runner
RUN adduser -D -H -s /sbin/nologin appuser
USER appuser
WORKDIR /app

COPY --from=builder /tmp/mcp_server /usr/local/bin/mcp_server

EXPOSE 3001

ENTRYPOINT ["/usr/local/bin/mcp_server"]
CMD ["-http", ":3001"]
