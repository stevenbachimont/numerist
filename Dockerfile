# Build stage
FROM node:18-alpine as build

WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# Production stage
FROM node:18-alpine

WORKDIR /app
COPY --from=build /app/package.json .
COPY --from=build /app/node_modules node_modules/
COPY --from=build /app/.svelte-kit .svelte-kit/
COPY --from=build /app/build build/

EXPOSE 3333
ENV NODE_ENV=production
ENV PORT=3333

CMD ["node", "-r", "dotenv/config", "build"] 