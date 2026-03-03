ARG RUNNER_IMAGE=nginx

# Build stage
FROM node:25.1 AS builder
WORKDIR /app

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

# Dev stage with both Node.js and Nginx
FROM builder AS dev

WORKDIR /app

RUN apt-get update && apt-get install --no-install-recommends -y nginx \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app /app
COPY default.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/build/ /usr/share/nginx/html/

CMD ["nginx", "-g", "daemon off;"]

# Runner
FROM ${RUNNER_IMAGE} AS runner

WORKDIR /app

ADD default.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/build/ /usr/share/nginx/html/
