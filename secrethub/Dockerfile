ARG ELIXIR_VERSION=1.13.4
ARG OTP_VERSION=24.3.4.9
ARG ALPINE_VERSION=3.18.6
ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-alpine-${ALPINE_VERSION}"
ARG RUNNER_IMAGE="alpine:${ALPINE_VERSION}"

FROM ${BUILDER_IMAGE} AS base

ARG BUILD_ENV=prod
ENV MIX_ENV=$BUILD_ENV

RUN echo "Build for $MIX_ENV environment started"

RUN apk update && apk add --no-cache build-base git python3 curl openssh

RUN mkdir -p ~/.ssh
RUN touch ~/.ssh/known_hosts
RUN ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts

RUN mix local.hex --force && mix local.rebar --force

WORKDIR /app

# install mix dependencies
COPY mix.exs mix.lock ./
COPY config config
RUN --mount=type=ssh mix deps.get --only $MIX_ENV
RUN mix deps.compile
COPY lib lib
COPY priv priv

FROM base AS dev

COPY .formatter.exs .formatter.exs
COPY .credo.exs .credo.exs
COPY test test

RUN mix sentry_recompile && mix compile

CMD [ "/bin/bash",  "-c \"while sleep 1000; do :; done\"" ]

FROM base AS builder

RUN mix release

FROM ${RUNNER_IMAGE} AS runner

# This is needed to connect the GitHub Container Registry package with our repository.
LABEL org.opencontainers.image.source https://github.com/semaphoreio/semaphore

ARG BUILD_ENV=prod
ENV MIX_ENV=$BUILD_ENV

# install runtime dependencies
RUN apk update && apk add --no-cache libstdc++ openssl ncurses-libs

# trivyfs security updates
RUN apk add --upgrade --no-cache libcrypto1.1 libssl1.1
HEALTHCHECK NONE

WORKDIR /app

# Create  unprivileged user to run the release
ENV USER="semaphore"
RUN addgroup -S "${USER}" && adduser -D -S "${USER}" -G "${USER}" && chown -R ${USER}:${USER} /app

# run as user
USER "${USER}"

# copy release executables
COPY --from=builder --chown="${USER}":"${USER}" /app/_build/${BUILD_ENV}/rel/secrethub ./

# copy migrations
COPY priv/repo/migrations priv/repo/migrations

ENTRYPOINT ["bin/secrethub"]

CMD ["start"]
