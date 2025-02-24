ARG ELIXIR_VERSION=1.18.2
ARG OTP_VERSION=25.3.2.16
ARG ALPINE_VERSION=3.21.2
ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-alpine-${ALPINE_VERSION}"
ARG RUNNER_IMAGE="alpine:${ALPINE_VERSION}"

FROM ${BUILDER_IMAGE} AS base

ARG BUILD_ENV=prod
ENV MIX_ENV=$BUILD_ENV

ARG APP_NAME
ENV APP_NAME=${APP_NAME}

RUN echo "Build of $APP_NAME for $MIX_ENV environment started"

RUN apk update && \
    apk add --no-cache \
    git libretls-static \
    openssh \
    bash

RUN mkdir -p -m 0600 ~/.ssh && ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts

RUN mix local.hex --force --if-missing && \
    mix local.rebar --force --if-missing

WORKDIR /app

COPY repository_hub/mix.* ./
COPY repository_hub/config config
COPY repository_hub/lib lib
COPY repository_hub/priv priv
COPY feature_provider ../feature_provider
RUN --mount=type=ssh mix do deps.get, deps.compile

#
# Dev stage
#
FROM base AS dev

COPY repository_hub/.formatter.exs .formatter.exs
COPY repository_hub/.credo.exs .credo.exs
COPY repository_hub/test test

RUN mix compile

CMD [ "/bin/ash",  "-c \"while sleep 1000; do :; done\"" ]

#
# Builder stage
# Basically, just create the mix release.
#
FROM base AS builder

RUN mix release

FROM ${RUNNER_IMAGE} AS runner

# This is needed to connect the GitHub Container Registry package with our repository.
LABEL org.opencontainers.image.source https://github.com/semaphoreio/semaphore

HEALTHCHECK NONE

ARG APP_NAME
ENV APP_NAME=${APP_NAME}
ENV MIX_ENV="prod"

# install runtime dependencies
RUN apk update && apk add --no-cache libstdc++ openssl ncurses-libs openssh-keygen

WORKDIR /app

# Create a non root user
RUN adduser -D default -h /app
USER default

COPY --from=builder --chown=default /app/_build/prod/rel/repository_hub_service/ .
COPY --from=builder --chown=default /app/priv/repo/migrations priv/repo/migrations

CMD ["/app/bin/repository_hub_service", "start"]
