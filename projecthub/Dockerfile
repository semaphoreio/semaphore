ARG ELIXIR_VERSION=1.12.3
ARG OTP_VERSION=24.3.4.17
ARG ALPINE_VERSION=3.20.9

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-alpine-${ALPINE_VERSION}"
ARG RUNNER_IMAGE="alpine:${ALPINE_VERSION}"

FROM ${BUILDER_IMAGE} AS base

ARG BUILD_ENV=prod
ENV MIX_ENV=$BUILD_ENV

ARG APP_NAME
ENV APP_NAME=${APP_NAME}

RUN echo "Build of $APP_NAME for $MIX_ENV environment started"

# install build dependencies
RUN apk update && \
  apk add --no-cache \
  openssh \
  git \
  openssl \
  ncurses-libs \
  libstdc++

RUN mkdir -p ~/.ssh
RUN touch ~/.ssh/known_hosts
RUN ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts

WORKDIR /app

# install hex + rebar
RUN mix local.hex --force --if-missing && \
  mix local.rebar --force --if-missing

# install mix dependencies
COPY projecthub/mix.exs projecthub/mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY projecthub/config/config.exs projecthub/config/${MIX_ENV}.exs projecthub/config/_silent_lager.exs config/
COPY feature_provider ../feature_provider
RUN mix deps.compile
# copy the rest of the config files
COPY projecthub/config/ config/

# Compile the release
COPY projecthub/lib lib
COPY projecthub/priv/repo/migrations priv/repo/migrations

FROM base AS dev

COPY projecthub/.formatter.exs .formatter.exs
COPY projecthub/.credo.exs .credo.exs
COPY projecthub/test test

RUN mix compile

CMD [ "/bin/bash",  "-c \"while sleep 1000; do :; done\"" ]

FROM base AS builder

RUN mix compile

RUN mix release

FROM ${RUNNER_IMAGE} AS runner

# This is needed to connect the GitHub Container Registry package with our repository.
LABEL org.opencontainers.image.source=https://github.com/semaphoreio/semaphore

HEALTHCHECK NONE

RUN apk update && \
  apk add --no-cache \
  openssh-keygen openssl ncurses-libs libstdc++

WORKDIR "/app"
RUN chown nobody /app

ENV MIX_ENV="prod"

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/projecthub ./

USER nobody

CMD ["/app/bin/projecthub", "start"]
