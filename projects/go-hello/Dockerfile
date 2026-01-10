FROM golang:1.22-alpine AS builder
WORKDIR /src

COPY go.mod ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/server .

FROM alpine:3.20
WORKDIR /app
COPY --from=builder /out/server /app/server

EXPOSE 8080
ENV PORT=8080
CMD ["/app/server"]
