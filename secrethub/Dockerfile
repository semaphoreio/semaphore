ARG ELIXIR_VERSION=1.13.4
ARG OTP_VERSION=24.2.2
ARG ALPINE_VERSION=3.22.2
ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-alpine-${ALPINE_VERSION}"
ARG RUNNER_IMAGE="alpine:${ALPINE_VERSION}"

FROM ${BUILDER_IMAGE} AS base

ARG BUILD_ENV=prod
ENV MIX_ENV=$BUILD_ENV

RUN echo "Build for $MIX_ENV environment started"

RUN apk update && apk add --no-cache build-base git python3 curl bash openssh

RUN mkdir -p ~/.ssh
RUN touch ~/.ssh/known_hosts
RUN ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts

RUN mix local.hex --force && mix local.rebar --force

WORKDIR /app

# install mix dependencies
COPY secrethub/mix.exs secrethub/mix.lock ./
COPY secrethub/config config
COPY feature_provider ../feature_provider
RUN mix deps.get --only $MIX_ENV && mix deps.compile
COPY secrethub/lib lib
COPY secrethub/priv priv

FROM base AS dev

COPY secrethub/.formatter.exs .formatter.exs
COPY secrethub/.credo.exs .credo.exs
COPY secrethub/test test

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

HEALTHCHECK NONE

WORKDIR /app

# Create  unprivileged user to run the release
ENV USER="semaphore"
RUN addgroup -S "${USER}" && adduser -D -S "${USER}" -G "${USER}" && chown -R ${USER}:${USER} /app

# run as user
USER "${USER}"

# copy release executables and migrations
COPY --from=builder --chown="${USER}":"${USER}" /app/_build/${BUILD_ENV}/rel/secrethub ./
COPY --from=builder --chown="${USER}":"${USER}" /app/priv/repo/migrations priv/repo/migrations

ENTRYPOINT ["bin/secrethub"]

CMD ["start"]
