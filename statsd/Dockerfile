ARG NODE_VERSION=22
ARG ALPINE_VERSION=3.22
ARG BASE_IMAGE="node:${NODE_VERSION}-alpine${ALPINE_VERSION}"
ARG RUNNER_IMAGE="alpine:${ALPINE_VERSION}"

FROM ${BASE_IMAGE} AS base

WORKDIR /app
COPY Makefile .
COPY localConfig.js .
COPY package.json .
RUN npm install

FROM base AS dev

CMD [ "/bin/ash",  "-c \"while sleep 1000; do :; done\"" ]

FROM ${RUNNER_IMAGE} AS runner

# This is needed to connect the GitHub Container Registry package with our repository.
LABEL org.opencontainers.image.source=https://github.com/semaphoreio/semaphore

EXPOSE 8125
HEALTHCHECK NONE

# statsd only needs the node runtime, so the runner builds on plain Alpine and
# installs `nodejs` from apk rather than inheriting node:*-alpine. That keeps
# npm, npx, corepack and yarn — and the node-tar they bundle, which carries
# CVE-2026-59873 (decompression bomb) — out of *every* layer, instead of
# deleting them in a later layer and relying on the scanner honouring the
# whiteout. It also leaves node visible to trivy as an apk package, so real
# node CVEs still surface, and drops the image from ~178MB to ~60MB.
#
# trivyfs security updates
RUN apk upgrade --no-cache && \
  apk add --no-cache nodejs make netcat-openbsd tcpdump && \
  rm -rf /var/cache/apk/* /tmp/* /var/tmp/*

WORKDIR /app
RUN chown nobody /app

USER nobody

COPY --from=base --chown=nobody:root /app/node_modules /app/node_modules
COPY --from=base --chown=nobody:root /app/package.json /app/package.json
COPY --from=base --chown=nobody:root /app/localConfig.js /app/localConfig.js

CMD [ "/bin/sh", "-c", "./node_modules/.bin/statsd localConfig.js" ]
