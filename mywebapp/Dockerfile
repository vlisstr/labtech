# mywebapp — application container.
#
# We use the Alpine variant of the official Node image — the resulting image
# is ~5x smaller than the Debian-based one. For Node.js we don't need a
# multi-stage build: there is no compile step to discard, and the dependency
# layer is already cached via the "COPY package*.json + npm install" pattern.

FROM node:18-alpine

WORKDIR /app

# 1) Dependency layer — rebuilt only when package.json/package-lock.json change.
COPY app/package*.json ./
RUN npm install --omit=dev --no-audit --no-fund && npm cache clean --force

# 2) Application code — changes most often, so it goes last.
COPY app/ ./

# 3) Entrypoint script: run migrations, then exec the server.
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh \
 && chown -R node:node /app

# Drop root privileges — minimum-rights principle.
USER node

EXPOSE 5200

ENTRYPOINT ["docker-entrypoint.sh"]
