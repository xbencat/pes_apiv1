# Makefile for PES APIv1 - Loan Management System

# Default Docker Compose file for local development
COMPOSE_FILE = compose/local/docker-compose.yml

# === Main Commands ===

# Build the Docker image
build:
	@echo "Building Docker image..."
	docker compose -f $(COMPOSE_FILE) build

# Start the application (API + Database + Migrations)
up:
	@echo "Starting PES APIv1 application..."
	docker compose -f $(COMPOSE_FILE) up -d
	@echo "Application started successfully!"
	@echo "API Documentation: http://localhost/api/docs"
	@echo "API Base URL: http://localhost/api"

# Stop the application
down:
	@echo "Stopping PES APIv1 application..."
	docker compose -f $(COMPOSE_FILE) down

# View application logs
logs:
	@echo "Showing application logs..."
	docker compose -f $(COMPOSE_FILE) logs -f

# === Development Commands ===

# Open shell in the API container
shell:
	@echo "Opening shell in API container..."
	docker compose -f $(COMPOSE_FILE) exec api /bin/bash

# Restart the application
restart: down up

# Clean up everything (containers, volumes, images)
clean:
	@echo "Cleaning up Docker resources..."
	docker compose -f $(COMPOSE_FILE) down -v
	docker system prune -f

# === Testing Commands ===

# Test API endpoints
test:
	@echo "Testing API endpoints..."
	@curl -s http://localhost/api/docs > /dev/null && echo "API is responding" || echo "API is not responding"

# === Help ===

help:
	@echo "PES APIv1 - Available Commands:"
	@echo ""
	@echo "Main Commands:"
	@echo "  make build    - Build the Docker image"
	@echo "  make up       - Start the application"
	@echo "  make down     - Stop the application"
	@echo "  make logs     - View application logs"
	@echo ""
	@echo "Development:"
	@echo "  make shell    - Open shell in API container"
	@echo "  make restart  - Restart the application"
	@echo "  make clean    - Clean up all Docker resources"
	@echo ""
	@echo "Testing:"
	@echo "  make test     - Test if API is responding"
	@echo ""
	@echo "Quick Start:"
	@echo "  cp compose/local/.env.example compose/local/.env"
	@echo "  make build && make up"

# Default target
.DEFAULT_GOAL := help
