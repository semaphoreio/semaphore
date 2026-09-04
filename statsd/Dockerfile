ARG NODE_VERSION=22
ARG ALPINE_VERSION=3.20
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

FROM base AS runner

# This is needed to connect the GitHub Container Registry package with our repository.
LABEL org.opencontainers.image.source https://github.com/semaphoreio/semaphore

EXPOSE 8125
HEALTHCHECK NONE

# trivyfs security updates
RUN apk add --upgrade --no-cache && \
  apk add --no-cache make netcat-openbsd tcpdump && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /app
RUN chown nobody /app

USER nobody

COPY --from=base --chown=nobody:root /app/node_modules /app/node_modules
COPY --from=base --chown=nobody:root /app/localConfig.js /app/localConfig.js

CMD [ "/bin/sh", "-c", "./node_modules/.bin/statsd localConfig.js" ]
