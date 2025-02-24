FROM elixir:1.14-alpine

WORKDIR /app
RUN apk update && apk add git gpg openssh inotify-tools make
RUN mix local.hex --force \
  && mix local.rebar --force
