FROM python:3.7.9-slim-buster

########################################################################
# Dockerfile Version:   19.03.1
# Software:             genomes-catalog-update
# Developer:            Tatiana Gurbich <tgurbich@ebi.ac.uk>
# Description:          scripts to fetch data
########################################################################

LABEL maintainer="Microbiome Informatics Team www.ebi.ac.uk/metagenomics"

RUN apt-get update && rm -rf /var/lib/apt/lists/*

COPY requirements.txt /requirements.txt
RUN pip install --no-cache-dir -r /requirements.txt

COPY scripts/* /tools/
RUN chmod a+x /tools/*
ENV PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/tools
