FROM continuumio/miniconda3

LABEL maintainer="Ekaterina Sakharova <kates@ebi.ac.uk>"

LABEL base_image="continuumio/miniconda3"
LABEL version="1"
LABEL software="eggnog"
LABEL software.version="2.1.3"

RUN conda install -c bioconda eggnog-mapper --yes --freeze-installed && conda clean -afy

ENV PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/tools
ENV PATH=/opt/conda/bin:${PATH}
