# Use a more recent, stable Python image
FROM python:3.11-slim

LABEL maintainer="Microbiome Informatics Team www.ebi.ac.uk/metagenomics"
LABEL software="python"
LABEL software.version="3.11"
LABEL description="Python base image, includes commonly used packages"
LABEL website="https://github.com/EBI-Metagenomics/genomes-pipeline"
LABEL license="Apache 2.0"

# Set environment variables to prevent Python from writing pyc files and buffer stdout/stderr
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Install required packages
RUN python -m pip install --upgrade pip && \
    pip install --no-cache-dir \
        requests==2.28.2 \
        retry==0.9.2 \
        xmltodict==0.12.0 \
        pandas==2.0.1 \
        numpy==1.24.3 \
        jsonschema==4.21.0

# Set working directory (optional, useful if adding scripts later)
WORKDIR /app
