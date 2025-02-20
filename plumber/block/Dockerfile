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
COPY block/mix.exs block/mix.lock ./
COPY definition_validator/mix.exs definition_validator/mix.lock ../definition_validator/
COPY job_matrix/mix.exs job_matrix/mix.lock ../job_matrix/
COPY looper/mix.exs looper/mix.lock ../looper/
COPY proto/mix.exs proto/mix.lock ../proto/
COPY spec/mix.exs spec/mix.lock ../spec/
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY block/config/config.exs block/config/${MIX_ENV}.exs config/
COPY definition_validator/config/config.exs ../definition_validator/config/
COPY job_matrix/config/config.exs ../job_matrix/config/
COPY looper/config/config.exs ../looper/config/
COPY proto/config/config.exs ../proto/config/
COPY spec/config/config.exs ../spec/config/
RUN mix deps.compile
# copy the rest of the config files
COPY block/config/ config/

# Compile the release
COPY block/lib lib
COPY block/priv/ecto_repo/migrations priv/ecto_repo/migrations
COPY block/priv/repos priv/repos
COPY definition_validator/lib ../definition_validator/lib
COPY job_matrix/lib ../job_matrix/lib
COPY looper/lib ../looper/lib
COPY proto/lib ../proto/lib
COPY spec/lib ../spec/lib
COPY spec/priv ../spec/priv

FROM base AS dev

COPY block/.formatter.exs .formatter.exs
COPY block/.credo.exs .credo.exs
COPY block/test test

RUN mix compile

CMD [ "/bin/bash",  "-c \"while sleep 1000; do :; done\"" ]
