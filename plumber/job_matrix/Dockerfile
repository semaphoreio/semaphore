ARG ELIXIR_VERSION=1.11.4
ARG OTP_VERSION=24.3.4.13
ARG UBUNTU_VERSION=focal-20230126

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

WORKDIR /app

# install hex + rebar
RUN mix local.hex --force --if-missing && \
    mix local.rebar --force --if-missing

# install mix dependencies
COPY job_matrix/mix.exs job_matrix/mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY job_matrix/config/config.exs job_matrix/config/${MIX_ENV}.exs config/
RUN mix deps.compile
# copy the rest of the config files
COPY job_matrix/config/ config/

# Compile the release
COPY job_matrix/lib lib

FROM base AS dev

COPY job_matrix/.formatter.exs .formatter.exs
COPY job_matrix/.credo.exs .credo.exs
COPY job_matrix/test test

RUN mix compile

CMD [ "/bin/bash",  "-c \"while sleep 1000; do :; done\"" ]
