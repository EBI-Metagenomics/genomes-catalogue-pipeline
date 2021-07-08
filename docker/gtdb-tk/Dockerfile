FROM continuumio/miniconda3

LABEL software="GTDB-Tk"
LABEL software.version="1.5.1"
LABEL description="A toolkit for assigning objective taxonomic classifications to bacterial and archaeal genomes."
LABEL website="https://github.com/Ecogenomics/GTDBTk"
LABEL license="GPLv3"

RUN conda install -c conda-forge -c bioconda -c defaults gtdbtk && conda clean -afy

# Workdir
RUN mkdir /data
WORKDIR /data

# Entrypoint
CMD ["/bin/bash", "-c"]
