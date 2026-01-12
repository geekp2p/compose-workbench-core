FROM node:20-alpine

# Install dependencies for building native modules
RUN apk add --no-cache \
    python3 \
    make \
    g++

WORKDIR /app

# Copy package files
COPY package.json /app/

# Install dependencies
RUN npm install --omit=dev

# Copy source code
COPY src /app/src

# Create data directory for message storage
RUN mkdir -p /app/data

# Expose ports (actual ports will be dynamically assigned by libp2p)
EXPOSE 4001 4002

# Environment variables
ENV NODE_ENV=production
ENV CHAT_TOPIC=p2p-chat-default

# Run the application
CMD ["npm", "start"]
