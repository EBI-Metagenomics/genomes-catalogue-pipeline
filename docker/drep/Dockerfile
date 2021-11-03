FROM continuumio/miniconda3

LABEL maintainer="Microbiome Informatics Team www.ebi.ac.uk/metagenomics"

LABEL base_image="continuumio/miniconda3"
LABEL version="1"
LABEL software="dRep"
LABEL software.version="3.2.2"

RUN conda install -c bioconda python=3.7 drep --yes --freeze-installed && conda clean -afy

ENV PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/tools
ENV PATH=/opt/conda/bin:${PATH}

COPY drep-wrapper.sh \
    /tools/

RUN chmod a+x /tools/*

ENV PATH="/tools:${PATH}"