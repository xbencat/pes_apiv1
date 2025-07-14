# Makefile for managing Docker Compose environments

# Build the Docker image
build:
	@echo "Building Docker image..."
	docker compose -f compose/local/docker-compose.yml build

# --- Local Environment ---
up-local:
	@echo "Starting local environment..."
	docker compose -f compose/local/docker-compose.yml up -d

down-local:
	@echo "Stopping local environment..."
	docker compose -f compose/local/docker-compose.yml down

logs-local:
	@echo "Showing logs for local environment..."
	docker compose -f compose/local/docker-compose.yml logs -f

# --- Stage Environment ---
up-stage:
	@echo "Starting stage environment..."
	docker compose -f compose/stage/docker-compose.yml up -d

down-stage:
	@echo "Stopping stage environment..."
	docker compose -f compose/stage/docker-compose.yml down

logs-stage:
	@echo "Showing logs for stage environment..."
	docker compose -f compose/stage/docker-compose.yml logs -f

# --- Production Environment ---
up-production:
	@echo "Starting production environment..."
	docker compose -f compose/production/docker-compose.yml up -d

down-production:
	@echo "Stopping production environment..."
	docker compose -f compose/production/docker-compose.yml down

logs-production:
	@echo "Showing logs for production environment..."
	docker compose -f compose/production/docker-compose.yml logs -f
