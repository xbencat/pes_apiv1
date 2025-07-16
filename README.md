# PES APIv1

This is a REST API for the Portal of Electronic Services (PES), a loan management system for managing loans to natural persons. The project is built with FastAPI and PostgreSQL, providing endpoints for loan retrieval and management.

## Assignment Context

This API is part of a web application for loan evidence and management for natural persons. The API provides basic information about loans and involved parties (Debtor and Guarantor) to an external web service - Portal of Electronic Services (PES), through which clients can view information about their loans, upload documents, and edit contact details.

## Prerequisites

- **Docker**
- **Docker Compose** (or `docker compose` plugin)
- No additional dependencies required

## Installation and Setup

### 1. Create Environment Configuration

Copy the example environment file:

```bash
cp compose/local/.env.example compose/local/.env
```

The default values are configured for local development and don't need modification.

### 2. Build and Start the Application

```bash
# Build the Docker image
make build

# Start all services (API + PostgreSQL + migrations)
make up
```

This starts:
- **FastAPI application** on port 80
- **PostgreSQL database** with provided sample data
- **Database migrator** that applies schema automatically

### 3. Verify Installation

The API will be available at: **http://localhost**

Access the interactive API documentation at: **http://localhost/api/docs**

### 4. Test the API

Example API calls:

```bash
# Get loans for user with EDUID
curl "http://localhost/api/loans?eduid=3000951357"
echo
echo

# Get specific loan details
curl "http://localhost/api/loans/e51843f6-dcb4-41b6-bc9d-3f138cc1241e?eduid=3000951357"
```

### 5. Stop the Application

```bash
make down
```

## API Implementation

### Implemented Endpoints

- `GET /api/loans` - Retrieve all loans for a user
- `GET /api/loans/{loan_id}` - Retrieve specific loan details

### User Identification

The API supports the assignment requirement of dual identification methods:

**Option 1: EDUID (Implemented)**
```
GET /api/loans?eduid=3000951357
```

**Option 2: Personal Details (Available)**
The infrastructure supports lookup by:
- first_name + last_name + person_id (birth number) + birth_date

### Database

- Uses the provided PostgreSQL database (cmdb_a2-part.sql)
- No new tables created (as per assignment requirements)
- Utilizes existing views for optimized queries
- All foreign key relationships properly mapped

## Project Structure

```
├── compose/local/           # Docker Compose configuration
│   ├── docker-compose.yml   # Main compose file
│   ├── .env.example         # Environment template
│   └── init-db/            # Database initialization scripts
├── pes_apiv1/              # Application source code
│   ├── db/                 # Database models and DAOs
│   ├── web/api/            # API endpoints and schemas
│   └── settings.py         # Configuration management
├── Dockerfile              # Application container definition
├── Makefile               # Build and run commands
└── README.md              # This file
```

## Development Notes

- **Framework**: FastAPI with async/await patterns
- **Database**: SQLAlchemy ORM with PostgreSQL
- **Validation**: Pydantic schemas with comprehensive validation
- **Logging**: Structured logging with Loguru
- **Error Handling**: Proper HTTP status codes and error messages

## Production Deployment Considerations

**Note**: This is a demo implementation. In production, the following would be added:

### CI/CD Pipeline
- **Branch-based deployment**: `main` → production, `stage` → staging, `develop` → tests only
- **GitHub Actions/GitLab CI** with automated testing, building, and deployment
- **Environment-specific Docker Compose** files for each environment

### Secrets Management
For sharing API keys (Google Maps, etc.) securely:

```bash
# Option 1: Encrypted environment files
git-crypt unlock
cp compose/local/.env.encrypted compose/local/.env

# Option 2: External secrets (Vault, AWS Secrets Manager)
make secrets-pull-local
```

### Additional Production Features
- Infrastructure as Code (Terraform)
- Kubernetes deployment manifests
- Monitoring and logging (Prometheus, ELK)
- Database migrations with rollback
- Blue-green deployments
