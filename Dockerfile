########################
# Devcontainer Image
########################
# Build the local devcontainer on top of a runtime image.
# Prefer a prebuilt zyra-scheduler image when provided; otherwise use Python for dev.
ARG ZYRA_SCHEDULER_IMAGE=python:3.11-slim
FROM ${ZYRA_SCHEDULER_IMAGE}

ARG DEBIAN_FRONTEND=noninteractive

# Ensure we have permissions to install packages even if the base image is rootless
USER root

# Base tools commonly needed in this repo
RUN apt-get update && apt-get install -y \
    curl git build-essential ffmpeg && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Poetry (available for local workflows; no-op if unused)
ENV POETRY_HOME="/opt/poetry"
ENV PATH="$POETRY_HOME/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/.local/bin:$PATH"
RUN curl -sSL https://install.python-poetry.org | python3 - || true

# Install Node.js 18.x and Codex CLI
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get update && apt-get install -y nodejs && \
    npm install -g @openai/codex && \
    npm cache clean --force && rm -rf /var/lib/apt/lists/*

# Ensure zyra S3 backend dependencies are present for CLI usage
RUN python3 -m pip install --no-cache-dir boto3

WORKDIR /app

# Keep the container running for interactive devcontainer sessions
CMD ["sleep", "infinity"]
