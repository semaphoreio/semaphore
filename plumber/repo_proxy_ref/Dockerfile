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
COPY repo_proxy_ref/mix.exs repo_proxy_ref/mix.lock ./
COPY proto/mix.exs proto/mix.lock ../proto/
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY repo_proxy_ref/config/config.exs config/
COPY proto/config/config.exs ../proto/config/
RUN mix deps.compile

# Compile the release
COPY repo_proxy_ref/lib lib
COPY proto/lib ../proto/lib

FROM base AS dev

RUN mix compile

CMD [ "/bin/bash",  "-c \"while sleep 1000; do :; done\"" ]

FROM base AS builder

RUN mix release

FROM ${RUNNER_IMAGE} AS runner

HEALTHCHECK NONE

RUN apt-get update -y && apt-get install --no-install-recommends -y ca-certificates wget libstdc++6 openssl libncurses5 locales openssh-client \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

RUN GRPC_HEALTH_PROBE_VERSION=v0.4.24 && \
    wget -qO/bin/grpc_health_probe https://github.com/grpc-ecosystem/grpc-health-probe/releases/download/${GRPC_HEALTH_PROBE_VERSION}/grpc_health_probe-linux-amd64 && \
    chmod +x /bin/grpc_health_probe

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
