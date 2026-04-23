FROM myoung34/github-runner:ubuntu-jammy

ENV DEBIAN_FRONTEND=noninteractive

# System deps — only what can't come from pyproject.toml
RUN apt-get update && apt-get install -y --no-install-recommends \
    # C-extension build deps (coincurve, cryptography wheels)
    build-essential \
    pkg-config \
    libssl-dev \
    libffi-dev \
    libgmp-dev \
    # protobuf compiler — binary tool, not installable via pip
    protobuf-compiler \
    # PPA management
    software-properties-common \
    # Utilities
    curl \
    git \
    make \
    && rm -rf /var/lib/apt/lists/*

# Python 3.11 + 3.12 via deadsnakes
RUN add-apt-repository ppa:deadsnakes/ppa -y && \
    apt-get update && apt-get install -y --no-install-recommends \
    python3.11 python3.11-dev python3.11-venv \
    python3.12 python3.12-dev python3.12-venv \
    && rm -rf /var/lib/apt/lists/*

# uv — the only Python tool we pre-install
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

# Sanity check
RUN python3.11 --version && python3.12 --version && uv --version && protoc --version