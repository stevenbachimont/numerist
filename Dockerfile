# Étape de build
FROM node:18-alpine as build

WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# Étape de production
FROM node:18-alpine

WORKDIR /app
COPY --from=build /app/package.json .
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/.svelte-kit ./.svelte-kit

EXPOSE 3333

ENV PORT=3333
ENV HOST=0.0.0.0

CMD ["node", "build"] 