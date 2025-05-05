ARG ELIXIR_VERSION=1.14.3
ARG OTP_VERSION=25.2.3
ARG ALPINE_VERSION=3.18.0
ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-alpine-${ALPINE_VERSION}"

# Base stage with common dependencies
FROM ${BUILDER_IMAGE} AS base

# Set Wallaby env var
ENV START_WALLABY=true

# Install system dependencies including ChromeDriver
RUN apk update && \
    apk add --no-cache \
    build-base \
    git \
    python3 \
    curl \
    openssh \
    chromium \
    chromium-chromedriver \
    xvfb \
    bash \
    # Add additional dependencies that may be required
    ttf-freefont \
    fontconfig \
    dbus \
    && apk add --no-cache --upgrade busybox busybox-binsh ssl_client

# Set up Chrome for headless operation
ENV CHROME_BIN=/usr/bin/chromium-browser
ENV CHROME_PATH=/usr/lib/chromium/
ENV CHROME_DRIVER_PATH=/usr/bin/chromedriver

# Set up Elixir environment
WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy and compile dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get && mix deps.compile

# Copy application code
COPY . .

# Set Wallaby to use Chrome in headless mode
ENV WALLABY_DRIVER=chrome
ENV WALLABY_CHROME_HEADLESS=true

# Create directory for screenshots
RUN mkdir -p /app/out/screenshots
