FROM node:20-alpine

WORKDIR /app
COPY package.json /app/
RUN npm install --omit=dev

COPY server.js /app/server.js

EXPOSE 3000
ENV PORT=3000
CMD ["npm", "start"]
