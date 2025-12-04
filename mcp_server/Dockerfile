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

COPY mcp_server/go.mod mcp_server/go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go mod download

COPY mcp_server/cmd ./cmd
COPY mcp_server/pkg ./pkg
COPY mcp_server/test ./test

FROM base AS dev
RUN --mount=type=cache,target=/root/.cache/go-build \
    go build ./cmd/mcp_server
CMD ["sh", "-c", "while sleep 1000; do :; done"]

FROM base AS builder
RUN --mount=type=cache,target=/root/.cache/go-build \
    go build -o /tmp/mcp_server ./cmd/mcp_server && \
    go build -o /tmp/indexer ./cmd/indexer

# Build the documentation search index
# Docs are expected at /docs in this stage (copied from build context or external source)
FROM builder AS indexer
COPY docs /docs
RUN /tmp/indexer -docs=/docs -output=/tmp/docssearch_index

FROM alpine:${ALPINE_VERSION} AS runner
RUN adduser -D -H -s /sbin/nologin appuser
WORKDIR /app

COPY --from=builder /tmp/mcp_server /usr/local/bin/mcp_server
COPY --from=indexer /tmp/docssearch_index /app/docssearch/index
COPY --from=indexer /docs /app/docssearch/docs

USER appuser

EXPOSE 3001

ENTRYPOINT ["/usr/local/bin/mcp_server"]
CMD ["-http", ":3001"]
