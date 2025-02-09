FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install -g npm@latest && \
    npm install @sveltejs/kit @sveltejs/adapter-node && \
    npm install

COPY . .
RUN npm run build

EXPOSE 3333
ENV PORT=3333
ENV HOST=0.0.0.0

CMD ["npm", "run", "preview", "--", "--host", "0.0.0.0", "--port", "3333"] 