ARG ELIXIR_VERSION=1.18.1
ARG OTP_VERSION=26.2.5.6
ARG ALPINE_VERSION=3.21.2

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

FROM base AS dev

COPY priv/ecto_repo/migrations priv/ecto_repo/migrations

RUN apk add --no-cache \
    inotify-tools bash make busybox-extras openssh-keygen gpg openssh-client vim

COPY .formatter.exs .formatter.exs
COPY .credo.exs .credo.exs
COPY test test

RUN mix compile

CMD [ "/bin/ash",  "-c \"while sleep 1000; do :; done\"" ]

FROM base AS builder

RUN mix compile --warnings-as-errors
RUN mix sentry.package_source_code
RUN mix release

FROM ${RUNNER_IMAGE} AS runner

# This is needed to connect the GitHub Container Registry package with our repository.
LABEL org.opencontainers.image.source https://github.com/semaphoreio/semaphore

HEALTHCHECK NONE

RUN apk update && \
    apk add --no-cache \
    openssh-keygen \
    ncurses-libs \
    libstdc++

# Create a non root user
RUN adduser -D default -h /app
USER default

WORKDIR /app

COPY --chown=default --from=builder /app/_build/prod/rel/hooks_processor/ .

CMD ["/app/bin/hooks_processor", "start"]
