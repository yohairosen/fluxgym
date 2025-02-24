# Base image with CUDA 12.2
FROM nvidia/cuda:12.2.2-base-ubuntu22.04

# Install system dependencies
RUN apt-get update -y && apt-get install -y \
    python3-pip \
    python3-dev \
    git \
    build-essential \
    && rm -rf /var/lib/apt/lists/*  # Clean up APT cache to reduce image size

# Define environment variables for UID and GID
ENV PUID=${PUID:-1000}
ENV PGID=${PGID:-1000}

# Create a group and user with the specified GID and UID
RUN groupadd -g "${PGID}" appuser && \
    useradd -m -s /bin/sh -u "${PUID}" -g "${PGID}" appuser

WORKDIR /app

# Copy and install main application dependencies
COPY ./requirements.txt ./requirements.txt
RUN python3 -m pip install --upgrade pip && \
    pip install --no-cache-dir -r ./requirements.txt

# Clone sd-scripts from kohya-ss and install dependencies
RUN git clone -b sd3 https://github.com/kohya-ss/sd-scripts && \
    cd sd-scripts && \
    pip install --no-cache-dir -r ./requirements.txt && \
    cd .. && rm -rf sd-scripts  # Clean up after installation

# Install Torch, Torchvision, and Torchaudio for CUDA 12.2
RUN pip install --no-cache-dir torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu122/torch_stable.html

# Fix for issue #325
RUN pip install --no-cache-dir triton==3.2.0
# Change ownership of the /app directory
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Copy fluxgym application code
COPY . ./fluxgym

EXPOSE 7860

ENV GRADIO_SERVER_NAME="0.0.0.0"

WORKDIR /app/fluxgym

# Run fluxgym Python application
CMD ["python3", "./app.py"]
