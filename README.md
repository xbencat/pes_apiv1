# PES APIv1

This is a REST API for the Portal of Electronic Services (PES), a loan management system. The project is built with FastAPI and follows a modern, scalable structure.

## Project Structure

The project is organized into the following main directories:

```
├── compose/            # Docker Compose files for different environments (local, stage, production).
├── pes_apiv1/          # The main application source code.
│   ├── db/             # Database models, migrations, and data access objects (DAO).
│   ├── web/            # FastAPI application, API endpoints, and request/response schemas.
│   ├── settings.py     # Application configuration, loaded from environment variables.
│   └── __main__.py     # Application entrypoint.
├── tests/              # Automated tests for the application.
├── Dockerfile          # Defines the Docker image for the application.
├── Makefile            # Provides simple commands for managing the project.
└── pyproject.toml      # Defines project dependencies and tool configurations.
```

## Local Development

To run the application locally, you need to have Docker and Docker Compose installed.

### 1. Initial Setup

First, you need to create a local environment file. This file will hold your secret credentials and local configuration. You can do this by copying the example file:

```bash
cp compose/local/.env.example compose/local/.env
```

The default values in the `.env` file are suitable for local development, so you don't need to change anything for now.

### 2. Build and Run the Application

With the environment file in place, you can build and run the application using the provided `Makefile`:

```bash
make build
make up-local
```

This will start the FastAPI application, a PostgreSQL database, and a migrator service that automatically applies database migrations.

The API will be available at `http://localhost:8000`.

### 3. Accessing the API Documentation

Once the application is running, you can access the interactive Swagger UI documentation at:

[http://localhost:8000/api/docs](http://localhost:8000/api/docs)

### 4. Stopping the Application

To stop the local environment, run:

```bash
make down-local
```