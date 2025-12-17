ARG ALPINE_VERSION="3.23.0"
ARG ELIXIR_VERSION="1.18.3"
ARG ERLANG_VERSION="26.2.5.5"
ARG RUNNER_IMAGE="alpine:${ALPINE_VERSION}"
ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${ERLANG_VERSION}-alpine-${ALPINE_VERSION}"

FROM ${BUILDER_IMAGE} AS base

ARG BUILD_ENV=prod
ENV MIX_ENV=$BUILD_ENV

RUN echo "Build for $MIX_ENV environment started"

RUN apk update && apk add --no-cache build-base git python3 curl openssh

RUN mix local.hex --force && mix local.rebar --force

RUN mkdir -p ~/.ssh
RUN touch ~/.ssh/known_hosts
RUN ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts

WORKDIR /app

COPY auth/mix.* ./
COPY auth/config config
COPY feature_provider ../feature_provider
RUN mix do deps.get, deps.compile

COPY auth/lib lib

FROM base AS dev

RUN apk add --no-cache \
    inotify-tools bash make busybox gnupg openssh-client

COPY auth/.formatter.exs .formatter.exs
COPY auth/.credo.exs .credo.exs
COPY auth/test test

RUN mix compile

CMD [ "/bin/ash",  "-c \"while sleep 1000; do :; done\"" ]

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

COPY --from=builder --chown="${USER}":"${USER}" /app/_build/${BUILD_ENV}/rel/auth ./

ENTRYPOINT ["bin/auth"]

CMD ["start"]