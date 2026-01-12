# Multi-stage build for minimal final image
# Stage 1: Build the application
FROM golang:1.21-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git gcc musl-dev

# Set working directory
WORKDIR /app

# Copy go.mod and go.sum first (for better caching)
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN CGO_ENABLED=1 GOOS=linux go build -a -installsuffix cgo -o p2p-chat .

# Stage 2: Create minimal runtime image
FROM alpine:latest

# Install runtime dependencies
RUN apk --no-cache add ca-certificates libc6-compat

# Set working directory
WORKDIR /app

# Copy binary from builder
COPY --from=builder /app/p2p-chat .

# Create data directory
RUN mkdir -p /app/data

# Expose no specific ports (P2P uses random ports)
# EXPOSE is not needed for libp2p as it negotiates ports

# Set environment variables
ENV CHAT_TOPIC=p2p-chat-default
ENV DATA_DIR=/app/data

# Run the application
CMD ["./p2p-chat"]
