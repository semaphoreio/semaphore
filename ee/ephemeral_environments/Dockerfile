ARG ELIXIR_VERSION=1.18.4
ARG OTP_VERSION=28.0.2
ARG ALPINE_VERSION=3.22.1
ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-alpine-${ALPINE_VERSION}"
ARG RUNNER_IMAGE="alpine:${ALPINE_VERSION}"

FROM ${BUILDER_IMAGE} AS base

ARG BUILD_ENV=prod
ENV MIX_ENV=$BUILD_ENV

RUN echo "Build for $MIX_ENV environment started"

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

RUN apk update && \
    apk add --no-cache \
    git openssh-keygen openssl ncurses-libs libstdc++

# Create a non root user
RUN adduser -D default -h /app
USER default

WORKDIR /app

COPY --chown=default --from=builder /app/_build/prod/rel/ephemeral_environments/ .
COPY --chown=default --from=builder /app/priv/repo/migrations /app/migrations

CMD ["sh", "-c", "bin/ephemeral_environments eval \"EphemeralEnvironments.Release.migrate()\" && bin/ephemeral_environments start"]
