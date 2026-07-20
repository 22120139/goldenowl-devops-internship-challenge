# syntax=docker/dockerfile:1.7

# =========================
# Stage 1: Build
# =========================
FROM node:20.20.2-alpine AS build

WORKDIR /app

COPY package.json package-lock.json ./

RUN --mount=type=cache,target=/root/.npm \
    npm ci

COPY . .

RUN npm run build \
    && npm prune --omit=dev \
    && npm cache clean --force


# =========================
# Stage 2: Runtime
# =========================
FROM node:20.20.2-alpine AS runtime

ENV NODE_ENV=production \
    NPM_CONFIG_UPDATE_NOTIFIER=false \
    NPM_CONFIG_FUND=false

WORKDIR /app

COPY --from=build --chown=node:node /app/package.json ./package.json
COPY --from=build --chown=node:node /app/node_modules ./node_modules
COPY --from=build --chown=node:node /app/dist ./dist

USER node

EXPOSE 3000

CMD ["npm", "start"]