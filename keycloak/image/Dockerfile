ARG KEYCLOAK_VERSION=25.0.6
ARG BASE_IMAGE=registry.access.redhat.com/ubi9:9.5
ARG BUILDER_IMAGE=quay.io/keycloak/keycloak:${KEYCLOAK_VERSION}
ARG RUNNER_IMAGE=quay.io/keycloak/keycloak:${KEYCLOAK_VERSION}

FROM ${BASE_IMAGE} AS base

WORKDIR /app
RUN yum update -y && yum install postgresql -y && yum clean all
COPY docker-entrypoint.sh docker-entrypoint.sh

FROM ${BUILDER_IMAGE} AS builder

WORKDIR /opt/keycloak
RUN /opt/keycloak/bin/kc.sh build \
  --db=postgres \
  --health-enabled=true \
  --metrics-enabled=true \
  --features=persistent-user-sessions

FROM ${RUNNER_IMAGE} AS runner

# This is needed to connect the GitHub Container Registry package with our repository.
LABEL org.opencontainers.image.source https://github.com/semaphoreio/semaphore

HEALTHCHECK NONE

# Create a non root user
USER 0
RUN set -x \
  && mkdir -p /opt/keycloak \
  && echo "keycloak:x:10001:10001:keycloak user:/opt/keycloak:/sbin/nologin" >> /etc/passwd \
  && echo "keycloak:x:10001:" >> /etc/group \
  && chown -R keycloak:keycloak /opt/keycloak

COPY --chown=keycloak:keycloak --from=base /usr/bin/createdb /usr/bin/createdb
COPY --chown=keycloak:keycloak --from=base /usr/bin/dropdb /usr/bin/dropdb
COPY --chown=keycloak:keycloak --from=base /usr/lib64/ /usr/lib64/
COPY --chown=keycloak:keycloak --from=base /app/docker-entrypoint.sh /app/docker-entrypoint.sh
COPY --chown=keycloak:keycloak --from=builder /opt/keycloak/ /opt/keycloak/
COPY --chown=keycloak:keycloak themes/semaphore/ /opt/keycloak/themes/semaphore/

USER keycloak

ENTRYPOINT ["bash", "/app/docker-entrypoint.sh"]
