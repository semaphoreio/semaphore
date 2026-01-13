ARG ELIXIR_VERSION=1.13.4
ARG OTP_VERSION=24.2.2
ARG ALPINE_VERSION=3.22.2
ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-alpine-${ALPINE_VERSION}"
ARG RUNNER_IMAGE="alpine:${ALPINE_VERSION}"
ARG MIX_ENV="prod"

# build stage
FROM ${BUILDER_IMAGE} AS base

ARG BUILD_ENV=prod
ENV MIX_ENV=$BUILD_ENV

RUN echo "Build for $MIX_ENV environment started"

# install build dependencies
RUN apk update && apk add --no-cache build-base git python3 curl

# sets work dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force \
    && mix local.rebar --force

# install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV

# copy compile configuration files
RUN mkdir config
COPY config config
COPY priv priv
COPY lib lib

# compile dependencies
RUN mix deps.compile

FROM base AS dev

COPY .formatter.exs .formatter.exs
COPY .credo.exs .credo.exs
COPY test test
RUN mix sentry_recompile && mix compile --warnings-as-errors

FROM base AS builder

# assemble release
RUN mix release

# app stage
FROM ${RUNNER_IMAGE} AS runner

# This is needed to connect the GitHub Container Registry package with our repository.
LABEL org.opencontainers.image.source https://github.com/semaphoreio/semaphore

ARG BUILD_ENV=prod
ENV MIX_ENV=$BUILD_ENV

HEALTHCHECK NONE

# install runtime dependencies
RUN apk update && apk add --no-cache libstdc++ openssl ncurses-libs \
    && apk add --no-cache --upgrade busybox busybox-binsh ssl_client

WORKDIR /app

# Create  unprivileged user to run the release
ENV USER="semaphore"
RUN addgroup -S "${USER}" && adduser -D -S "${USER}" -G "${USER}" && chown -R ${USER}:${USER} /app
USER "${USER}"

# copy release executables
COPY --from=builder --chown="${USER}":"${USER}" /app/_build/"${MIX_ENV}"/rel/branch_hub ./

# copy migrations
COPY priv/repo/migrations priv/repo/migrations

ENTRYPOINT ["bin/branch_hub"]

CMD ["start"]
