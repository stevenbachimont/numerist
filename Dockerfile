# Build stage
FROM node:18-alpine as build

WORKDIR /app
COPY package*.json ./
RUN npm install
RUN npm install @sveltejs/adapter-node
COPY . .
RUN npm run build

# Production stage
FROM node:18-alpine

WORKDIR /app
COPY --from=build /app/package.json .
COPY --from=build /app/build .
COPY --from=build /app/node_modules ./node_modules

EXPOSE 3333
ENV NODE_ENV=production
ENV PORT=3333

CMD ["node", "index.js"] 