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
# CGO_ENABLED=1 is required for BadgerDB
RUN CGO_ENABLED=1 GOOS=linux go build -a -installsuffix cgo -o p2p-chat ./cmd/p2p-chat

# Stage 2: Create minimal runtime image
FROM alpine:latest

# Install runtime dependencies (ca-certificates for HTTPS, curl for health checks)
RUN apk --no-cache add ca-certificates curl

# Create non-root user
RUN addgroup -g 1000 p2p && \
    adduser -D -u 1000 -G p2p p2p

# Set working directory
WORKDIR /app

# Copy binary from builder
COPY --from=builder /app/p2p-chat .

# Create data directory and set ownership
RUN mkdir -p /app/data && chown -R p2p:p2p /app

# Switch to non-root user
USER p2p

# Environment variables
ENV DATA_DIR=/app/data
ENV CHAT_TOPIC=p2p-chat-default

# Run the application
CMD ["./p2p-chat"]
