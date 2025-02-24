# Base image with CUDA 12.2
FROM nvidia/cuda:12.2.2-base-ubuntu22.04

# Install system dependencies, including python3-venv, libgl1-mesa-glx, and libglib2.0-0 for OpenCV
RUN apt-get update -y && apt-get install -y \
    python3-pip \
    python3-dev \
    python3-venv \
    git \
    build-essential \
    libgl1-mesa-glx \
    libglib2.0-0

# Define environment variables for UID and GID
ENV PUID=${PUID:-1000}
ENV PGID=${PGID:-1000}

# Create a group and a user with the specified UID/GID
RUN groupadd -g "${PGID}" appuser && \
    useradd -m -s /bin/sh -u "${PUID}" -g "${PGID}" appuser

WORKDIR /app

### ---------------------- KOHYA ENVIRONMENT ---------------------- ###

# Create a virtual environment for Kohya
RUN python3 -m venv /app/kohya-venv

# Use Kohya venv
ENV PATH="/app/kohya-venv/bin:$PATH"

# Upgrade pip inside Kohya's venv
RUN /app/kohya-venv/bin/pip install --upgrade pip

# Clone and install kohya-ss/sd-scripts inside Kohya's venv
RUN git clone -b sd3 https://github.com/kohya-ss/sd-scripts && \
    cd sd-scripts && \
    /app/kohya-venv/bin/pip install --no-cache-dir -r ./requirements.txt && \
    /app/kohya-venv/bin/pip install --no-cache-dir .

### ---------------------- FLUXGYM ENVIRONMENT ---------------------- ###

# Create a virtual environment for FluxGym
RUN python3 -m venv /app/fluxgym-venv

# Use FluxGym venv
ENV PATH="/app/fluxgym-venv/bin:$PATH"

# Upgrade pip inside FluxGym's venv
RUN /app/fluxgym-venv/bin/pip install --upgrade pip

# Install main application dependencies inside FluxGym's venv
COPY ./requirements.txt ./requirements.txt
RUN /app/fluxgym-venv/bin/pip install --no-cache-dir -r ./requirements.txt

# Install Torch, Torchvision, and Torchaudio for CUDA 12.2 in FluxGym's venv
RUN /app/fluxgym-venv/bin/pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu122/torch_stable.html

# Set PYTHONPATH so that FluxGym can access Kohya's installed modules and the sd-scripts folder.
ENV PYTHONPATH="/app/sd-scripts:/app/kohya-venv/lib/python3.10/site-packages:$PYTHONPATH"

RUN chown -R appuser:appuser /app

# (No cleanup here: we preserve the sd-scripts directory so train_network is available)

# Run application as non-root
USER appuser

# Copy FluxGym application code
COPY . ./fluxgym

EXPOSE 7860

ENV GRADIO_SERVER_NAME="0.0.0.0"

WORKDIR /app/fluxgym

# Run FluxGym using its own virtual environment
CMD ["/app/fluxgym-venv/bin/python3", "./app.py"]
