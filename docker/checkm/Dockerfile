FROM mambaorg/micromamba:0.27.0

ENV VERSION=1.1.3=py_1

LABEL maintainer="Microbiome Informatics Team www.ebi.ac.uk/metagenomics"

LABEL base_image="mambaorg/micromamba:0.27.0"
LABEL version="1"
LABEL software="checkm"
LABEL software.version="1.1.3"

RUN micromamba install -y -n base -c bioconda -c conda-forge matplotlib-base checkm-genome=${VERSION} && micromamba clean --all --yes

ENV PATH=/opt/conda/bin:${PATH}

