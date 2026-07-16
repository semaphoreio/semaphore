ARG BASE_IMAGE=ruby:3.3.11-slim-bookworm

FROM ${BASE_IMAGE} as base

ARG BUILD_ENV=production
ENV RAILS_ENV=$BUILD_ENV

ARG APP_NAME
ENV APP_NAME=${APP_NAME}

RUN echo "Build of $APP_NAME for $RAILS_ENV environment started"

RUN apt-get update && apt-get install --no-install-recommends -y -qq \
  libpq5 \
  libjemalloc2 \
  libgnutls30 \
  openssl \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

ENV LANG=C.UTF-8 \
  BUNDLE_APP_CONFIG=/app/vendor/bundle \
  BUNDLE_PATH=/app/vendor/bundle \
  GEM_HOME=/app/vendor/bundle

RUN gem update --system 3.5.23
RUN gem install bundler -v '2.6.2' --no-document
RUN gem install net-imap -v '0.5.15' --no-document && \
  rm -rf /usr/local/lib/ruby/gems/3.3.0/gems/net-imap-0.4.21 && \
  rm -f /usr/local/lib/ruby/gems/3.3.0/specifications/net-imap-0.4.21.gemspec \
    /usr/local/lib/ruby/gems/3.3.0/specifications/default/net-imap-0.4.21.gemspec

FROM base AS builder

# Install necessary packages
RUN apt-get update && apt-get install --no-install-recommends -y --allow-downgrades -qq \
  build-essential \
  curl \
  wget \
  git \
  locales \
  linux-libc-dev \
  libpq-dev \
  zlib1g-dev \
  libyaml-dev \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

ENV BUNDLE_JOBS=4 \
  BUNDLE_RETRY=3

# ---------------------------------------------------------------------------
# grpc-gem: compile the forked grpc C-core (clone -> submodule init -> native
# build) ONCE into an isolated, cacheable layer. Its only cache key is
# docker/grpc.Gemfile, so it is rebuilt only when the grpc fork ref changes --
# unrelated Gemfile.lock churn no longer triggers the ~20-40 min recompile. The
# compiled gem lands in $BUNDLE_PATH and is copied forward by the stages below.
# ---------------------------------------------------------------------------
FROM builder AS grpc-gem

WORKDIR /grpc-build

COPY docker/grpc.Gemfile Gemfile
RUN bundle install --jobs=${BUNDLE_JOBS} && rm -f "$BUNDLE_PATH/config"

FROM builder AS dev

WORKDIR /app

# Reuse the pre-compiled grpc from the cached grpc-gem layer, so this stage's
# bundle install skips the C-core build and only installs the remaining gems.
COPY --from=grpc-gem ${BUNDLE_PATH} ${BUNDLE_PATH}
COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs=${BUNDLE_JOBS}

COPY . .

ARG TARGETPLATFORM
RUN export JEMALLOC_PATH=$(if [ "$TARGETPLATFORM" = "linux/arm64" ]; then echo "/usr/lib/aarch64-linux-gnu/libjemalloc.so.2"; else echo "/usr/lib/x86_64-linux-gnu/libjemalloc.so.2"; fi)
ENV LD_PRELOAD=$JEMALLOC_PATH

EXPOSE 3000
CMD ["/usr/bin/bash"]

FROM builder as production-builder

WORKDIR /app

# Reuse the pre-compiled grpc from the cached grpc-gem layer (see dev stage).
COPY --from=grpc-gem ${BUNDLE_PATH} ${BUNDLE_PATH}
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local deployment true && \
    bundle config set --local without 'development test' && \
    bundle config set --local clean 'true' && \
    bundle config set --local no-cache 'true' && \
    bundle install --jobs=${BUNDLE_JOBS} && \
    rm -rf $BUNDLE_PATH/ruby/3.3.0/cache/*

FROM base as runner

# This is needed to connect the GitHub Container Registry package with our repository.
LABEL org.opencontainers.image.source https://github.com/semaphoreio/semaphore

WORKDIR /app

HEALTHCHECK NONE

ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2

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
