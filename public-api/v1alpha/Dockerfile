ARG ELIXIR_VERSION=1.13.4
ARG OTP_VERSION=24.2.2
ARG ALPINE_VERSION=3.19.0
ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-alpine-${ALPINE_VERSION}"
ARG RUNNER_IMAGE="alpine:${ALPINE_VERSION}"

FROM ${BUILDER_IMAGE} AS base

ENV TERM=xterm
ARG BUILD_ENV=prod
ENV MIX_ENV=$BUILD_ENV

RUN echo "Build for $MIX_ENV environment started"

RUN apk update && apk add --no-cache build-base git python3 curl openssh bash

RUN mkdir -p ~/.ssh
RUN touch ~/.ssh/known_hosts
RUN ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts

RUN mix local.hex --force && mix local.rebar --force

RUN mkdir api
WORKDIR /app

# install mix dependencies
COPY public-api/v1alpha/mix.exs public-api/v1alpha/mix.lock ./
COPY public-api/v1alpha/config config
COPY feature_provider ../../feature_provider
RUN mix deps.get --only $MIX_ENV
RUN mix deps.compile
COPY public-api/v1alpha/lib lib
COPY public-api/v1alpha/priv priv

# dev stage
FROM base AS dev

COPY public-api/v1alpha/.formatter.exs .formatter.exs
COPY public-api/v1alpha/.credo.exs .credo.exs
COPY public-api/v1alpha/test test

RUN mix compile

CMD [ "/bin/bash",  "-c \"while sleep 1000; do :; done\"" ]

# builder stage
FROM base AS builder

RUN mix release

# runner stage
FROM ${RUNNER_IMAGE} AS runner

# This is needed to connect the GitHub Container Registry package with our repository.
LABEL org.opencontainers.image.source https://github.com/semaphoreio/semaphore

ARG BUILD_ENV="prod"
ENV MIX_ENV=$BUILD_ENV

# We don't need Docker health checks, since these containers
# are intended to run in Kubernetes pods, which have probes.
HEALTHCHECK NONE

# install runtime dependencies
RUN apk update \
    && apk add --no-cache libstdc++ openssl ncurses-libs libcrypto3 libssl3 zlib

ENV USER="front"

WORKDIR /home/front/app

# Create  unprivileged user to run the release
RUN \
    addgroup \
    -g 1000 \
    -S "${USER}" \
    && adduser \
    -s /bin/sh \
    -u 1000 \
    -G "${USER}" \
    -h "/home/${USER}" \
    -D "${USER}" \
    && su "${USER}"

# run as user
USER "${USER}"

# copy release executables
COPY --from=builder --chown="${USER}":"${USER}" /app/_build/"${MIX_ENV}"/rel/pipelines_api ./

ENTRYPOINT ["bin/pipelines_api"]

CMD ["start"]
