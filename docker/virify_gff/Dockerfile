FROM python:3.9.15-slim-bullseye

LABEL maintainer="Microbiome Informatics Team www.ebi.ac.uk/metagenomics"

RUN pip install --no-cache-dir biopython==1.80 pandas==1.5.2

COPY virify_gff.py /tools/

RUN chmod a+x /tools/*

ENV PATH "${PATH}:/tools"