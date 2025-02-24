ARG ELIXIR_VERSION=1.13.4
ARG OTP_VERSION=24.3.4.17
ARG ALPINE_VERSION=3.20.3
ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-alpine-${ALPINE_VERSION}"
ARG RUNNER_IMAGE="alpine:${ALPINE_VERSION}"

FROM ${BUILDER_IMAGE} as base

ARG BUILD_ENV=prod
ENV MIX_ENV=$BUILD_ENV

RUN echo "Build for $MIX_ENV environment started"

RUN apk update && \
    apk add --no-cache \
    git libretls-static openssh-client

RUN mix local.hex --force --if-missing && \
    mix local.rebar --force --if-missing

RUN mkdir -p ~/.ssh
RUN touch ~/.ssh/known_hosts
RUN ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts

WORKDIR /app

COPY github_notifier/mix.* ./
COPY github_notifier/config config
COPY feature_provider ../feature_provider
RUN --mount=type=ssh mix do deps.get, deps.compile

COPY github_notifier/lib lib

FROM base as dev

RUN apk add --no-cache \
    inotify-tools bash make busybox-extras openssh-keygen gpg openssh-client

COPY github_notifier/.formatter.exs .formatter.exs
COPY github_notifier/.credo.exs .credo.exs
COPY github_notifier/test test

RUN mix compile

CMD [ "/bin/ash",  "-c \"while sleep 1000; do :; done\"" ]

FROM base as builder

RUN mix compile --warnings-as-errors
RUN mix deps.compile sentry --force
RUN mix release

FROM ${RUNNER_IMAGE} as runner

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

COPY --chown=default --from=builder /app/_build/prod/rel/github_notifier/ .

CMD ["/app/bin/github_notifier", "start"]
