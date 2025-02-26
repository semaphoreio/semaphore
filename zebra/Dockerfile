ARG ELIXIR_VERSION=1.13.4
ARG OTP_VERSION=24.3.4.17
ARG UBUNTU_VERSION=focal-20241011
ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-ubuntu-${UBUNTU_VERSION}"
ARG RUNNER_IMAGE="ubuntu:${UBUNTU_VERSION}"

FROM ${BUILDER_IMAGE} AS base

ARG BUILD_ENV=prod
ENV MIX_ENV=$BUILD_ENV

RUN echo "Build for $MIX_ENV environment started"

# Install dev tools and openssh-client
RUN apt-get update && \
  apt-get install -y --no-install-recommends ca-certificates curl gnupg git openssh-client

RUN mix local.hex --force \
  && mix local.rebar --force

RUN mkdir -p ~/.ssh
RUN touch ~/.ssh/known_hosts
RUN ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts

WORKDIR /app

COPY zebra/mix.exs .
COPY zebra/mix.lock .
COPY zebra/config config
COPY feature_provider ../feature_provider
RUN mix do deps.get, deps.compile

WORKDIR /app

COPY zebra/lib lib

WORKDIR /app

FROM base AS dev

COPY zebra/.formatter.exs .formatter.exs
COPY zebra/.credo.exs .credo.exs
COPY zebra/priv/legacy_repo/migrations priv/legacy_repo/migrations
COPY zebra/.credo.exs .credo.exs
COPY zebra/test test

RUN mix compile

RUN echo "Sleeping forever..."
CMD [ "/bin/bash",  "-c \"while sleep 1000; do :; done\"" ]

FROM base AS builder

RUN mix release

FROM ${RUNNER_IMAGE} AS runner

# This is needed to connect the GitHub Container Registry package with our repository.
LABEL org.opencontainers.image.source https://github.com/semaphoreio/semaphore

ARG APP_NAME
ENV APP_NAME=${APP_NAME}
ARG BUILD_ENV=prod
ENV MIX_ENV=$BUILD_ENV

# install runtime dependencies
RUN apt-get update -y && apt-get install --no-install-recommends -y libstdc++6 openssl libncurses5 locales openssh-client inotify-tools \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR /app
RUN chown nobody /app

# Copy the mix release
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/${APP_NAME} ./

USER nobody

# We don't need Docker health checks, since these containers
# are intended to run in Kubernetes pods, which have probes.
HEALTHCHECK NONE

ENTRYPOINT ["bin/zebra"]

CMD ["start"]
