FROM quay.io/biocontainers/python:3.9--1

LABEL maintainer="Microbiome Informatics Team www.ebi.ac.uk/metagenomics"
LABEL software="GECCO"
LABEL software.version="0.9.8"

RUN pip install gecco-tool==0.9.8

# Run gecco-tool when the container launches
CMD ["gecco"]
