FROM python:3.11.4-slim-bullseye AS base

RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

RUN pip install poetry==1.8.2

RUN poetry config virtualenvs.create false
RUN poetry config cache-dir /tmp/poetry_cache

WORKDIR /app

COPY pyproject.toml poetry.lock ./

FROM base AS prod
RUN --mount=type=cache,target=/tmp/poetry_cache \
    poetry install --only main --no-dev

COPY . .

RUN apt-get purge -y gcc && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

CMD ["python", "-m", "pes_apiv1"]

FROM base AS dev
# Install all dependencies
RUN --mount=type=cache,target=/tmp/poetry_cache \
    poetry install

# Create PyCharm helpers directory
RUN mkdir -p /opt/.pycharm_helpers

# Install some additional tools that PyCharm might need
RUN pip install setuptools wheel

COPY . .

# Install the package in editable mode
RUN --mount=type=cache,target=/tmp/poetry_cache \
    poetry install --only-root

# Verify installation
CMD ["python", "-m", "pes_apiv1"]
