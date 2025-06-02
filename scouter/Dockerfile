ARG ELIXIR_VERSION=1.17.2
ARG OTP_VERSION=27.1
ARG ALPINE_VERSION=3.17.3
ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-alpine-${ALPINE_VERSION}"
ARG RUNNER_IMAGE="alpine:${ALPINE_VERSION}"


FROM ${BUILDER_IMAGE} AS base

ARG BUILD_ENV=prod
ENV MIX_ENV=$BUILD_ENV

ARG APP_NAME
ENV APP_NAME=${APP_NAME}

RUN echo "Build of $APP_NAME for $MIX_ENV environment started"


RUN apk update && \
    apk add --no-cache build-base git openssh

RUN mix local.hex --force --if-missing && \
    mix local.rebar --force --if-missing

WORKDIR /app

COPY mix.* ./
COPY config config
RUN mix do deps.get, deps.compile
COPY lib lib
COPY priv priv

FROM base AS dev
WORKDIR /app

COPY test test
COPY .formatter.exs .formatter.exs
COPY .credo.exs .credo.exs

CMD [ "/bin/ash",  "-c \"while sleep 1000; do :; done\"" ]

FROM base AS builder
WORKDIR /app

RUN mix compile --warnings-as-errors
RUN mix release

FROM ${RUNNER_IMAGE} AS runner
HEALTHCHECK NONE

# This is needed to connect the GitHub Container Registry package with our repository.
LABEL org.opencontainers.image.source https://github.com/semaphoreio/semaphore

RUN apk update && \
    apk add --no-cache \
    git openssh-keygen openssl ncurses-libs libstdc++

# Create a non root user
RUN adduser -D default -h /app
USER default

WORKDIR /app

COPY --chown=default --from=builder /app/_build/prod/rel/scouter/ .
COPY --chown=default --from=builder /app/priv/repo/migrations /app/migrations

CMD ["sh", "-c", "bin/scouter eval \"Scouter.Release.migrate()\" && bin/scouter start"]
