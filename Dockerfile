# Base image with CUDA 12.2
FROM nvidia/cuda:12.2.2-base-ubuntu22.04

# Install system dependencies, including python3-venv and libraries needed for OpenCV
RUN apt-get update -y && apt-get install -y \
    python3-pip \
    python3-dev \
    python3-venv \
    git \
    build-essential \
    libgl1-mesa-glx \
    libglib2.0-0

# Define environment variables for UID and GID (with defaults)
ENV PUID=${PUID:-1000} \
    PGID=${PGID:-1000}

# Create a group and a user with the specified UID/GID
RUN groupadd -g "${PGID}" appuser && \
    useradd -m -s /bin/sh -u "${PUID}" -g "${PGID}" appuser

WORKDIR /app

### ---------------------- KOHYA ENVIRONMENT ---------------------- ###
# Create a virtual environment for kohya-ss/sd-scripts
RUN python3 -m venv /app/kohya-venv
# Use the kohya virtual environment for subsequent commands
ENV PATH="/app/kohya-venv/bin:$PATH"
# Upgrade pip inside kohya-venv
RUN /app/kohya-venv/bin/pip install --upgrade pip
# Clone and install sd-scripts (including its package, e.g. "library")
RUN git clone -b sd3 https://github.com/kohya-ss/sd-scripts && \
    cd sd-scripts && \
    /app/kohya-venv/bin/pip install --no-cache-dir -r ./requirements.txt && \
    /app/kohya-venv/bin/pip install --no-cache-dir . 
# Remove the sd-scripts folder once installed
RUN rm -rf sd-scripts

### ---------------------- FLUXGYM ENVIRONMENT ---------------------- ###
# Create a separate virtual environment for FluxGym
RUN python3 -m venv /app/fluxgym-venv
# Use fluxgym-venv for subsequent commands
ENV PATH="/app/fluxgym-venv/bin:$PATH"
# Upgrade pip inside fluxgym-venv and install FluxGym dependencies
COPY ./requirements.txt ./requirements.txt
RUN /app/fluxgym-venv/bin/pip install --upgrade pip && \
    /app/fluxgym-venv/bin/pip install --no-cache-dir -r ./requirements.txt
# Install Torch, Torchvision, and Torchaudio for CUDA 12.2
RUN /app/fluxgym-venv/bin/pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu122/torch_stable.html

# Set PYTHONPATH so FluxGym can import modules installed in kohya-venv (e.g. "library")
ENV PYTHONPATH="/app/kohya-venv/lib/python3.10/site-packages:$PYTHONPATH"

# Ensure proper permissions
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Copy FluxGym application code into /app/fluxgym
COPY . ./fluxgym

EXPOSE 7860
ENV GRADIO_SERVER_NAME="0.0.0.0"

WORKDIR /app/fluxgym

# Run FluxGym using the fluxgym virtual environment (using system python3, which will pick up site‑packages)
CMD ["python3", "./app.py"]
