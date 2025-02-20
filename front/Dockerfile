ARG ELIXIR_VERSION=1.14.3
ARG OTP_VERSION=25.2.3
ARG ALPINE_VERSION=3.18.0
ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-alpine-${ALPINE_VERSION}"
ARG RUNNER_IMAGE="alpine:${ALPINE_VERSION}"

# -- base stage
FROM ${BUILDER_IMAGE} AS base

ARG BUILD_ENV=prod
ENV MIX_ENV=$BUILD_ENV

RUN echo "Build for $MIX_ENV environment started"

# install node 16.x
ENV ALPINE_MIRROR="http://dl-cdn.alpinelinux.org/alpine"
RUN echo "${ALPINE_MIRROR}/v3.18/main/" >> /etc/apk/repositories

# install build dependencies
RUN apk update && \
    apk add --no-cache build-base git python3 curl openssh && \
    apk add --no-cache --upgrade busybox busybox-binsh ssl_client && \
    apk add --no-cache nodejs npm --repository="http://dl-cdn.alpinelinux.org/alpine/v3.18/main/"

RUN mkdir -p -m 0600 ~/.ssh && ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts
# -- base stage

# -- elixir stage
FROM base AS elixir
WORKDIR /elixir
RUN mix local.hex --force \
    && mix local.rebar --force
COPY mix.* ./
RUN --mount=type=ssh mix do deps.get, deps.compile

COPY config config
COPY priv priv
COPY lib lib
COPY secrets secrets
COPY workflow_templates workflow_templates
COPY test test
COPY .formatter.exs ./
RUN mix sentry_recompile && mix compile --warnings-as-errors
# -- elixir stage

# -- node stage
FROM base AS node
WORKDIR /node
COPY assets/package.json assets/package-lock.json ./
RUN npm install
WORKDIR /assets
COPY assets /assets
RUN mv /node/node_modules /assets/node_modules
# -- node stage

# -- dev stage - for local development
FROM elixir AS dev
WORKDIR /app
RUN apk update \
    && apk add --no-cache chromium-chromedriver inotify-tools bash gnupg

COPY --from=elixir /elixir ./
COPY --from=node /assets ./assets
WORKDIR /app/assets
RUN node build.js
WORKDIR /app

CMD [ "/bin/ash",  "-c \"while sleep 1000; do :; done\"" ]
# -- dev stage

# -- builder stage - build artifacts are created here
FROM elixir AS builder
WORKDIR /app
COPY --from=elixir /elixir ./
COPY --from=node /assets ./assets
RUN mix assets.deploy
RUN mix release
# -- builder stage

# -- runner stage - final image
FROM ${RUNNER_IMAGE} AS runner

# This is needed to connect the GitHub Container Registry package with our repository.
LABEL org.opencontainers.image.source https://github.com/semaphoreio/semaphore

ARG BUILD_ENV=prod
ENV MIX_ENV=$BUILD_ENV

# We don't need Docker health checks, since these containers
# are intended to run in Kubernetes pods, which have probes.
HEALTHCHECK NONE

# install runtime dependencies
RUN apk update \
    && apk add --no-cache libstdc++ openssl ncurses-libs \
    && apk add --no-cache --upgrade busybox busybox-binsh ssl_client

ENV USER="front"

WORKDIR /home/front/app

# Create  unprivileged user to run the release
RUN \
    addgroup \
    -g 1000 \
    -S "${USER}" \
    && adduser \
    -s /bin/sh \
    -u 1000 \
    -G "${USER}" \
    -h "/home/${USER}" \
    -D "${USER}" \
    && su "${USER}"

# run as user
USER "${USER}"

# copy release executables
COPY --from=builder --chown="${USER}":"${USER}" /app/_build/"${MIX_ENV}"/rel/front ./

COPY workflow_templates workflow_templates

ENTRYPOINT ["bin/front"]

CMD ["start"]
# -- runner stage
