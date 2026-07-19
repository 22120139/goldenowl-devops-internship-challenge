FROM node:20.20.2-alpine

WORKDIR /app

COPY package.json package-lock.json ./

RUN npm ci --omit=dev && npm cache clean --force

COPY --chown=node:node . .

ENV NODE_ENV=production

EXPOSE 3000

USER node

CMD ["npm", "start"]