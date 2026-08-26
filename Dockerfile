# syntax=docker/dockerfile:1

FROM node:24-bookworm AS build

ARG DSH_CLIENT_COMMIT_HASH=a6a6edc6d93cbd58c7b6dde52c30ae1e11e80375

ENV COREPACK_ENABLE_DOWNLOAD_PROMPT=0
ENV DSH_CLIENT_COMMIT_HASH=${DSH_CLIENT_COMMIT_HASH}

WORKDIR /src

COPY . .

RUN corepack enable \
    && pnpm install --frozen-lockfile \
    && pnpm run build \
    && pnpm --filter @deepseek-ai/dsh deploy --legacy --prod /opt/dsh

FROM docker:27-cli AS docker-cli

FROM node:24-bookworm-slim

RUN apt-get update \
    && apt-get install --yes --no-install-recommends bash ca-certificates curl git openssh-client ripgrep \
    && rm -rf /var/lib/apt/lists/*

COPY --from=docker-cli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=build /opt/dsh /opt/dsh

ENV DSH_HOME=/var/lib/dsh \
    DSH_TELEMETRY_DISABLED=1 \
    DSH_PERMISSION_MODE=workspace-write \
    PATH=/opt/dsh/node_modules/.bin:${PATH}

WORKDIR /workspace

VOLUME ["/var/lib/dsh"]
EXPOSE 3080

HEALTHCHECK CMD curl --fail --silent http://127.0.0.1:3080/ >/dev/null || exit 1

# The current web profile binds to 0.0.0.0 by default. Do not override it
# here: that lets Docker port publishing and LAN access work out of the box.
ENTRYPOINT ["dsh", "web", "--no-open"]
