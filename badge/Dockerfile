ARG ELIXIR_VERSION=1.12.3
ARG OTP_VERSION=24.3.4.17
ARG ALPINE_VERSION=3.21.0

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-alpine-${ALPINE_VERSION}"
ARG RUNNER_IMAGE="alpine:${ALPINE_VERSION}"

FROM ${BUILDER_IMAGE} as base

ARG BUILD_ENV=prod
ENV MIX_ENV=$BUILD_ENV

RUN echo "Build for $MIX_ENV environment started"

RUN apk update && \
    apk add --no-cache \
    git libretls-static

RUN mix local.hex --force --if-missing && \
    mix local.rebar --force --if-missing

WORKDIR /app

COPY mix.* ./
COPY config config
RUN mix do deps.get, deps.compile

COPY lib lib
COPY assets assets

FROM base as dev

RUN apk add --no-cache \
    inotify-tools bash make busybox-extras openssh-keygen gpg openssh-client

COPY .formatter.exs .formatter.exs
COPY .credo.exs .credo.exs
COPY test test

RUN mix compile

CMD [ "/bin/ash",  "-c \"while sleep 1000; do :; done\"" ]

FROM base as builder

RUN mix compile
RUN mix deps.compile sentry --force
RUN mix release

FROM ${RUNNER_IMAGE} as runner

# This is needed to connect the GitHub Container Registry package with our repository.
LABEL org.opencontainers.image.source https://github.com/semaphoreio/semaphore

HEALTHCHECK NONE

# install runtime dependencies
RUN apk update \
    && apk add --no-cache libstdc++ openssl ncurses-libs \
    && apk add --no-cache --upgrade busybox busybox-binsh ssl_client

# Create a non root user
RUN adduser -D default -h /app
USER default

WORKDIR /app

COPY --chown=default --from=builder /app/_build/prod/rel/badges/ .
COPY assets assets

CMD ["/app/bin/badges", "start"]
