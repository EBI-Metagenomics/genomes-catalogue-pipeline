FROM continuumio/miniconda3

LABEL maintainer="Microbiome Informatics Team www.ebi.ac.uk/metagenomics"

LABEL base_image="continuumio/miniconda3"
LABEL version="1"
LABEL software="checkm"
LABEL software.version="1.1.3"

RUN conda install -c bioconda python=3.6 checkm-genome --yes --freeze-installed && conda clean -afy

ENV PATH=/opt/conda/bin:${PATH}

