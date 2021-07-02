FROM continuumio/miniconda3

LABEL maintainer="Ekaterina Sakharova <kates@ebi.ac.uk>"

LABEL base_image="continuumio/miniconda3"
LABEL version="1"
LABEL software="roary"
LABEL software.version="3.13.0"

RUN conda config --add channels r
RUN conda config --add channels defaults
RUN conda config --add channels conda-forge
RUN conda config --add channels bioconda
RUN conda install -c bioconda roary

#RUN conda install -c bioconda eggnog-mapper --yes --freeze-installed && conda clean -afy

#ENV PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/tools
#ENV PATH=/opt/conda/bin:${PATH}
