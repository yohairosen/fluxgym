# Base image with CUDA 12.2
FROM nvidia/cuda:12.2.2-base-ubuntu22.04

# Install system dependencies
RUN apt-get update -y && apt-get install -y \
    python3-pip \
    python3-dev \
    git \
    build-essential  # Install dependencies for building extensions

# Define environment variables for UID and GID
ENV PUID=${PUID:-1000}
ENV PGID=${PGID:-1000}

# Create a group with the specified GID
RUN groupadd -g "${PGID}" appuser
# Create a user with the specified UID and GID
RUN useradd -m -s /bin/sh -u "${PUID}" -g "${PGID}" appuser

WORKDIR /app

### ---------------------- KOHYA ENVIRONMENT ---------------------- ###

# Create and activate a virtual environment for Kohya
RUN python3 -m venv /app/kohya-venv
ENV PATH="/app/kohya-venv/bin:$PATH"  # Ensure Kohya venv is used in this block

# Upgrade pip inside Kohya's venv
RUN /app/kohya-venv/bin/pip install --upgrade pip

# Clone and install kohya-ss/sd-scripts inside kohya-venv
RUN git clone -b sd3 https://github.com/kohya-ss/sd-scripts && \
    cd sd-scripts && \
    /app/kohya-venv/bin/pip install --no-cache-dir -r ./requirements.txt && \
    /app/kohya-venv/bin/pip install --no-cache-dir .  # Ensure 'library' is installed

### ---------------------- FLUXGYM ENVIRONMENT ---------------------- ###

# Create and activate a virtual environment for FluxGym
RUN python3 -m venv /app/fluxgym-venv
ENV PATH="/app/fluxgym-venv/bin:$PATH"  # Ensure FluxGym venv is used in this block

# Upgrade pip inside FluxGym's venv
RUN /app/fluxgym-venv/bin/pip install --upgrade pip

# Install main application dependencies inside FluxGym's venv
COPY ./requirements.txt ./requirements.txt
RUN /app/fluxgym-venv/bin/pip install --no-cache-dir -r ./requirements.txt

# Install Torch, Torchvision, and Torchaudio for CUDA 12.2 inside FluxGym's venv
RUN /app/fluxgym-venv/bin/pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu122/torch_stable.html

# Set PYTHONPATH so FluxGym can access Kohya's installed modules
ENV PYTHONPATH="/app/kohya-venv/lib/python3.10/site-packages:$PYTHONPATH"

RUN chown -R appuser:appuser /app

# Delete redundant requirements.txt and sd-scripts directory
RUN rm -r ./sd-scripts
RUN rm ./requirements.txt

# Run application as non-root
USER appuser

# Copy fluxgym application code
COPY . ./fluxgym

EXPOSE 7860

ENV GRADIO_SERVER_NAME="0.0.0.0"

WORKDIR /app/fluxgym

# Run fluxgym using its own virtual environment, but with access to Kohya's modules
CMD ["/app/fluxgym-venv/bin/python3", "./app.py"]
