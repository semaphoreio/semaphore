ARG TERRAFORM_VERSION=1.16.5
FROM hashicorp/terraform:${TERRAFORM_VERSION} AS runner

# This is needed to connect the GitHub Container Registry package with our repository.
LABEL org.opencontainers.image.source https://github.com/semaphoreio/semaphore

HEALTHCHECK NONE

WORKDIR /terraform

RUN apk --no-cache upgrade && apk add --no-cache curl

RUN adduser -D default -h /terraform
USER default

COPY . .

RUN terraform init -backend=false

ENTRYPOINT ["sh", "-c", "./scripts/entrypoint.sh"]
