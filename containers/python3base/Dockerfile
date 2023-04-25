FROM quay.io/biocontainers/python:3.9--1

LABEL maintainer="Microbiome Informatics Team www.ebi.ac.uk/metagenomics"
LABEL software="python"
LABEL software.version="3.9"
LABEL description="Python base image, includes the requests package"
LABEL website="https://github.com/EBI-Metagenomics/genomes-pipeline"
LABEL license="Apache 2.0"

RUN /usr/local/bin/python -m pip install --upgrade pip && \
    pip install --no-cache-dir \
    requests==2.28.2 \
    retry==0.9.2 \
    xmltodict==0.12.0 \
    pandas==2.0.1 \
    numpy==1.24.3
