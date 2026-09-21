ARG ELIXIR_VERSION=1.11.4
ARG OTP_VERSION=24.3.4.13
ARG UBUNTU_VERSION=jammy-20230126

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
# NOTE: the build context is the repository root (see DOCKER_BUILD_PATH in the
# Makefile) so that feature_provider, which lives outside the plumber/ tree,
# can be copied into the image.
COPY plumber/ppl/mix.exs plumber/ppl/mix.lock ./
COPY plumber/block/mix.exs plumber/block/mix.lock ../block/
COPY plumber/definition_validator/mix.exs plumber/definition_validator/mix.lock ../definition_validator/
COPY plumber/gofer_client/mix.exs plumber/gofer_client/mix.lock ../gofer_client/
COPY plumber/job_matrix/mix.exs plumber/job_matrix/mix.lock ../job_matrix/
COPY plumber/looper/mix.exs plumber/looper/mix.lock ../looper/
COPY plumber/proto/mix.exs plumber/proto/mix.lock ../proto/
COPY plumber/spec/mix.exs plumber/spec/mix.lock ../spec/
COPY feature_provider ../feature_provider
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY plumber/ppl/config/config.exs plumber/ppl/config/${MIX_ENV}.exs config/
COPY plumber/block/config/config.exs plumber/block/config/${MIX_ENV}.exs ../block/config/
COPY plumber/definition_validator/config/config.exs ../definition_validator/config/
COPY plumber/gofer_client/config/config.exs ../gofer_client/config/
COPY plumber/job_matrix/config/config.exs ../job_matrix/config/
COPY plumber/looper/config/config.exs ../looper/config/
COPY plumber/proto/config/config.exs ../proto/config/
COPY plumber/spec/config/config.exs ../spec/config/
RUN mix deps.compile
# copy the rest of the config files
COPY plumber/ppl/config/ config/

# Compile the release
COPY plumber/ppl/lib lib
COPY plumber/ppl/priv/ecto_repo/migrations priv/ecto_repo/migrations
COPY plumber/block/lib ../block/lib
COPY plumber/block/priv/ecto_repo/migrations ../block/priv/ecto_repo/migrations
COPY plumber/block/priv/repos ../block/priv/repos
COPY plumber/definition_validator/lib ../definition_validator/lib
COPY plumber/gofer_client/lib ../gofer_client/lib
COPY plumber/job_matrix/lib ../job_matrix/lib
COPY plumber/looper/lib ../looper/lib
COPY plumber/proto/lib ../proto/lib
COPY plumber/spec/lib ../spec/lib
COPY plumber/spec/priv ../spec/priv

FROM base AS dev

COPY plumber/ppl/.formatter.exs .formatter.exs
COPY plumber/ppl/.credo.exs .credo.exs
COPY plumber/ppl/test test

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
