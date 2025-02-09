# Étape de build
FROM node:18-alpine as build

WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# Étape de production avec Nginx
FROM nginx:alpine

WORKDIR /app
COPY --from=build /app/.svelte-kit/output/client /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 3333

CMD ["nginx", "-g", "daemon off;"] 