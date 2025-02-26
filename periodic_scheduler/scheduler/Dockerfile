ARG ELIXIR_VERSION=1.14.5
ARG OTP_VERSION=24.2.2
ARG UBUNTU_VERSION=jammy-20240808

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-ubuntu-${UBUNTU_VERSION}"
ARG RUNNER_IMAGE="ubuntu:${UBUNTU_VERSION}"

# --------------------------------------

FROM ${BUILDER_IMAGE} AS base

ARG BUILD_ENV=prod
ENV MIX_ENV=$BUILD_ENV

ARG APP_NAME
ENV APP_NAME=${APP_NAME}

RUN echo "Build of $APP_NAME for $MIX_ENV environment started"

# install build dependencies
RUN apt-get update -y && apt-get install --no-install-recommends -y build-essential git curl ca-certificates gnupg openssh-client \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

RUN mkdir -p ~/.ssh
RUN touch ~/.ssh/known_hosts
RUN ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts

WORKDIR /app

RUN mix local.hex --force --if-missing && \
    mix local.rebar --force --if-missing

# install mix dependencies
RUN mkdir scheduler
WORKDIR /app/scheduler

COPY periodic_scheduler/spec/mix.exs periodic_scheduler/spec/mix.lock ../spec/
COPY periodic_scheduler/definition_validator/mix.exs periodic_scheduler/definition_validator/mix.lock ../definition_validator/
COPY periodic_scheduler/scheduler/mix.exs periodic_scheduler/scheduler/mix.lock ./
COPY feature_provider ../../feature_provider
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

COPY periodic_scheduler/scheduler/config config/
COPY periodic_scheduler/spec/config/config.exs ../spec/config/
COPY periodic_scheduler/definition_validator/config/config.exs ../definition_validator/config/
RUN mix deps.compile

# copy the rest of the config files
#COPY scheduler/config config/

COPY periodic_scheduler/spec/lib ../spec/lib
COPY periodic_scheduler/spec/priv ../spec/priv
COPY periodic_scheduler/definition_validator/lib ../definition_validator/lib
COPY periodic_scheduler/scheduler/lib lib
COPY periodic_scheduler/scheduler/priv/periodics_repo/migrations priv/periodics_repo/migrations
COPY periodic_scheduler/scheduler/priv/front_repo/migrations priv/front_repo/migrations

# --------------------------------------

FROM base AS dev

COPY periodic_scheduler/scheduler/.formatter.exs .formatter.exs
COPY periodic_scheduler/scheduler/config/.credo.exs .credo.exs
COPY periodic_scheduler/scheduler/test test

RUN mix compile

# Set up dependencies from APT
ENV DEPS="apt-utils build-essential inotify-tools lsb-release sudo tmux unzip vim-tiny wget"
RUN apt-get update && apt-get install --no-install-recommends -y ${DEPS} && rm -rf /var/lib/apt/lists/*

# Download retry
ENV RETRY_URL=https://raw.githubusercontent.com/renderedtext/scripts/8f67b78cef7f5a7556777f59a5f290db8b23abe1/utility/retry

RUN wget -q ${RETRY_URL} && \
    mv retry /usr/local/bin && \
    chmod +x /usr/local/bin/retry

# Set up PostgreSQL client
ENV POSTGRES_VERSION=9.6

RUN sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && \
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - && \
    apt-get update && apt-get install --no-install-recommends -y postgresql-client-$(POSTGRES_VERSION)

HEALTHCHECK NONE

CMD [ "/bin/bash",  "-c \"while sleep 1000; do :; done\"" ]

# --------------------------------------
FROM base AS builder

RUN mix release


FROM ${RUNNER_IMAGE} AS runner

# This is needed to connect the GitHub Container Registry package with our repository.
LABEL org.opencontainers.image.source https://github.com/semaphoreio/semaphore

ENV MIX_ENV=prod

RUN apt-get update -y && \
  apt-get install --no-install-recommends -y bash locales openssl wget ca-certificates && \
  apt-get clean && rm -f /var/lib/apt/lists/*_* && \
  sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
  locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

COPY --from=builder --chown=nobody:root /app/scheduler/_build/${MIX_ENV}/rel/scheduler ./

USER nobody

HEALTHCHECK NONE

CMD ["/app/bin/scheduler", "start"]