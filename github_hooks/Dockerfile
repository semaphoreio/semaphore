ARG BASE_IMAGE=ruby:3.3.6-alpine
FROM ${BASE_IMAGE} as base

ARG BUILD_ENV=production
ENV RAILS_ENV=$BUILD_ENV

ARG APP_NAME
ENV APP_NAME=${APP_NAME}

RUN echo "Build of $APP_NAME for $RAILS_ENV environment on Alpine started"

# Install runtime dependencies, including gcompat and timezone data
RUN apk add --no-cache \
  postgresql-libs \
  jemalloc \
  gcompat \
  tzdata

ENV LANG=C.UTF-8 \
  BUNDLE_APP_CONFIG=/app/vendor/bundle \
  BUNDLE_PATH=/app/vendor/bundle \
  GEM_HOME=/app/vendor/bundle

RUN gem update --system 3.5.23
RUN gem install bundler -v '2.6.9' --no-document

FROM base AS builder

# Install build tools and development headers
RUN apk add --no-cache \
  build-base \
  curl \
  wget \
  git \
  linux-headers \
  zlib-dev \
  yaml-dev \
  postgresql-dev \
  jemalloc-dev \
  protobuf-dev

ENV BUNDLE_JOBS=4 \
  BUNDLE_RETRY=3

FROM builder AS dev

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs=${BUNDLE_JOBS}

COPY . .

ENV LD_PRELOAD=/usr/lib/libjemalloc.so.2

EXPOSE 3000
CMD ["/bin/sh"]

FROM builder as production-builder

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle config set --local deployment true && \
    bundle config set --local without 'development test' && \
    bundle config set --local clean 'true' && \
    bundle config set --local no-cache 'true' && \
    bundle config set --local force_ruby_platform.grpc true && \
    bundle config set --local force_ruby_platform.google-protobuf true && \
    bundle install --jobs=${BUNDLE_JOBS} && \
    rm -rf $BUNDLE_PATH/ruby/3.0.0/cache/*

FROM base as runner

# This is needed to connect the GitHub Container Registry package with our repository.
LABEL org.opencontainers.image.source https://github.com/semaphoreio/semaphore

WORKDIR /app

HEALTHCHECK NONE

ENV LD_PRELOAD=/usr/lib/libjemalloc.so.2

COPY --chown=nobody:root app app
COPY --chown=nobody:root script script
COPY --chown=nobody:root bin bin
COPY --chown=nobody:root config config
COPY --chown=nobody:root db db
COPY --chown=nobody:root lib lib
COPY --chown=nobody:root protobuffer protobuffer
COPY --chown=nobody:root config.ru config.ru
COPY --chown=nobody:root Rakefile Rakefile
COPY --chown=nobody:root sidekiq.ru sidekiq.ru
COPY --chown=nobody:root Gemfile Gemfile
COPY --chown=nobody:root Gemfile.lock Gemfile.lock
COPY --from=production-builder --chown=nobody:root $BUNDLE_PATH $BUNDLE_PATH

RUN mkdir -p /app/tmp && chown nobody:root /app/tmp

USER nobody

EXPOSE 3000
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]