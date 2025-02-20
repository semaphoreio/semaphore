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
COPY ppl/mix.exs ppl/mix.lock ./
COPY block/mix.exs block/mix.lock ../block/
COPY definition_validator/mix.exs definition_validator/mix.lock ../definition_validator/
COPY gofer_client/mix.exs gofer_client/mix.lock ../gofer_client/
COPY job_matrix/mix.exs job_matrix/mix.lock ../job_matrix/
COPY looper/mix.exs looper/mix.lock ../looper/
COPY proto/mix.exs proto/mix.lock ../proto/
COPY spec/mix.exs spec/mix.lock ../spec/
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY ppl/config/config.exs ppl/config/${MIX_ENV}.exs config/
COPY block/config/config.exs block/config/${MIX_ENV}.exs ../block/config/
COPY definition_validator/config/config.exs ../definition_validator/config/
COPY gofer_client/config/config.exs ../gofer_client/config/
COPY job_matrix/config/config.exs ../job_matrix/config/
COPY looper/config/config.exs ../looper/config/
COPY proto/config/config.exs ../proto/config/
COPY spec/config/config.exs ../spec/config/
RUN mix deps.compile
# copy the rest of the config files
COPY ppl/config/ config/

# Compile the release
COPY ppl/lib lib
COPY ppl/priv/ecto_repo/migrations priv/ecto_repo/migrations
COPY block/lib ../block/lib
COPY block/priv/ecto_repo/migrations ../block/priv/ecto_repo/migrations
COPY block/priv/repos ../block/priv/repos
COPY definition_validator/lib ../definition_validator/lib
COPY gofer_client/lib ../gofer_client/lib
COPY job_matrix/lib ../job_matrix/lib
COPY looper/lib ../looper/lib
COPY proto/lib ../proto/lib
COPY spec/lib ../spec/lib
COPY spec/priv ../spec/priv

FROM base AS dev

COPY ppl/.formatter.exs .formatter.exs
COPY ppl/.credo.exs .credo.exs
COPY ppl/test test

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

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

ARG APP_NAME
ENV APP_NAME=${APP_NAME}

# set runner ENV
ENV MIX_ENV="prod"

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/${APP_NAME} ./

USER nobody

CMD /app/bin/${APP_NAME} start
