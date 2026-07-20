FROM node:20.20.2-alpine AS dependencies

WORKDIR /app

COPY package.json package-lock.json ./

RUN npm ci --omit=dev \
    && npm cache clean --force


FROM node:20.20.2-alpine AS runtime

WORKDIR /app

ENV NODE_ENV=production

COPY --from=dependencies \
    --chown=node:node \
    /app/node_modules \
    ./node_modules

COPY --chown=node:node . .

EXPOSE 3000

USER node

CMD ["npm", "start"]