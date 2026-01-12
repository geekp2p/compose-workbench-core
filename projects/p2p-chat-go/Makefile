.PHONY: help build run clean docker-build docker-run test

help: ## Show this help
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

build: ## Build the application
	go build -o p2p-chat ./cmd/p2p-chat

run: ## Run the application
	go run ./cmd/p2p-chat

clean: ## Clean build artifacts
	rm -f p2p-chat
	rm -rf data/

docker-build: ## Build Docker image
	docker build -t p2p-chat-go:latest .

docker-run: ## Run Docker container
	docker compose up --build

test: ## Run tests
	go test -v ./...

mod-tidy: ## Tidy go modules
	go mod tidy

mod-download: ## Download go modules
	go mod download
