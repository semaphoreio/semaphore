ARG ELIXIR_VERSION=1.12.3
ARG OTP_VERSION=24.3.4.17
ARG ALPINE_VERSION=3.20.9
ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-alpine-${ALPINE_VERSION}"
ARG RUNNER_IMAGE="alpine:${ALPINE_VERSION}"

# build stage
FROM ${BUILDER_IMAGE} AS dev
ARG BUILD_ENV=prod
ENV MIX_ENV=$BUILD_ENV

RUN apk update && \
    apk upgrade --no-cache && \
    apk add --no-cache \
    git openssh-keygen openssl ncurses-libs libstdc++

# sets work dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force \
    && mix local.rebar --force

# install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV

COPY .formatter.exs .formatter.exs
COPY .credo.exs .credo.exs
COPY test test

# compile dependencies
RUN mix deps.compile

# copy compile configuration files
COPY config config

# copy assets
COPY priv priv

# compile project
COPY lib lib
RUN mix sentry_recompile && mix compile --warnings-as-errors

# copy runtime configuration file
COPY config/runtime.exs config/

# assemble release
RUN mix release

# app stageF
FROM ${RUNNER_IMAGE} AS runner
ENV MIX_ENV=prod

# This is needed to connect the GitHub Container Registry package with our repository.
LABEL org.opencontainers.image.source https://github.com/semaphoreio/semaphore

HEALTHCHECK NONE

RUN apk update && \
    apk upgrade --no-cache && \
    apk add --no-cache \
    openssh-keygen openssl ncurses-libs libstdc++

WORKDIR /app

# Create  unprivileged user to run the release
ENV USER="semaphore"
RUN addgroup -S "${USER}" && adduser -D -S "${USER}" -G "${USER}" && chown -R ${USER}:${USER} /app
USER "${USER}"

# copy release executables
COPY --from=dev --chown="${USER}":"${USER}" /app/_build/"${MIX_ENV}"/rel/notifications ./

# copy migrations
COPY priv priv

ENTRYPOINT ["bin/notifications"]

CMD ["start"]
