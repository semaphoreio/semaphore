ARG ELIXIR_VERSION=1.13.4
ARG OTP_VERSION=24.3.4.17
ARG UBUNTU_VERSION=jammy-20250404

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-ubuntu-${UBUNTU_VERSION}"
ARG RUNNER_IMAGE="ubuntu:${UBUNTU_VERSION}"

FROM ${BUILDER_IMAGE} AS base

ARG BUILD_ENV=prod
ENV MIX_ENV=$BUILD_ENV

ARG APP_NAME
ENV APP_NAME=${APP_NAME}

RUN echo "Build of $APP_NAME for $MIX_ENV environment started"

# install build dependencies
RUN apt-get update -y && apt-get install --no-install-recommends -y build-essential git curl ca-certificates gnupg openssh-client \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

RUN mix local.hex --force \
  && mix local.rebar --force

RUN mkdir -p ~/.ssh
RUN touch ~/.ssh/known_hosts
RUN ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts

WORKDIR /app

COPY mix.exs .
COPY mix.lock .
COPY config config
RUN mix do deps.get, deps.compile

COPY lib lib
COPY priv/ecto_repo/migrations priv/ecto_repo/migrations

FROM base AS dev

COPY .formatter.exs .formatter.exs
COPY .credo.exs .credo.exs
COPY test test

RUN mix compile

CMD [ "/bin/bash",  "-c \"while sleep 1000; do :; done\"" ]

FROM base AS builder

RUN mix release

FROM ${RUNNER_IMAGE} AS runner

# This is needed to connect the GitHub Container Registry package with our repository.
LABEL org.opencontainers.image.source https://github.com/semaphoreio/semaphore

HEALTHCHECK NONE

RUN apt-get update -y && apt-get install --no-install-recommends -y libstdc++6 openssl libncurses5 locales openssh-client \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*
# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR /app

RUN chown nobody /app

ENV MIX_ENV="prod"

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/pre_flight_checks ./

USER nobody

CMD /app/bin/pre_flight_checks start
