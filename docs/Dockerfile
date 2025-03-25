ARG BUILDER_IMAGE=node
ARG RUNNER_IMAGE=nginx


# Build stage
FROM ${BUILDER_IMAGE} AS builder
WORKDIR /app
ENV LOCALE en

COPY package.json package.json
COPY package-lock.json package-lock.json
COPY yarn.lock yarn.lock
COPY babel.config.js babel.config.js
COPY docusaurus.config.js docusaurus.config.js
COPY sidebars.js sidebars.js
COPY versions.json versions.json
COPY docs docs
COPY docs-drafts docs-drafts
COPY src src
COPY static static
COPY versioned_docs versioned_docs
COPY versioned_sidebars versioned_sidebars
COPY .markdownlint.json .markdownlint.json

RUN npm install --frozen-lockfile
RUN npm run clear
RUN npm run build

# Dev stage
FROM builder AS dev

WORKDIR /app

ADD default.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/build/ /usr/share/nginx/html/

# Runner
FROM ${RUNNER_IMAGE} AS runner

WORKDIR /app

ADD default.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/build/ /usr/share/nginx/html/


