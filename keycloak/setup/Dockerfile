ARG TERRAFORM_VERSION=1.15.0
FROM hashicorp/terraform:${TERRAFORM_VERSION} AS runner

# This is needed to connect the GitHub Container Registry package with our repository.
LABEL org.opencontainers.image.source https://github.com/semaphoreio/semaphore

HEALTHCHECK NONE

WORKDIR /terraform

RUN apk update && \
  apk upgrade --no-cache && \
  apk add --no-cache curl

RUN adduser -D default -h /terraform
USER default

COPY . .

ENTRYPOINT ["sh", "-c", "./scripts/entrypoint.sh"]
