FROM continuumio/miniconda3

LABEL maintainer="Ekaterina Sakharova <kates@ebi.ac.uk>"

RUN conda install -c bioconda/label/cf201901 python=3.6 checkm-genome


ENV PATH /opt/conda/envs/env/bin:$PATH