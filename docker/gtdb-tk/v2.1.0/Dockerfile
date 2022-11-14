FROM mambaorg/micromamba:0.27.0

LABEL software="GTDB-Tk"
LABEL software.version="2.1.0"
LABEL description="A toolkit for assigning objective taxonomic classifications to bacterial and archaeal genomes."
LABEL website="https://github.com/Ecogenomics/GTDBTk"
LABEL license="GPLv3"

# This is the conda package version
ENV VERSION=2.1.0-0

# numpy=1.9.3 is required to install gtdbtk
RUN micromamba install -y -n base -c bioconda -c conda-forge numpy=1.9.3 gtdbtk=${VERSION} && micromamba clean --all --yes

# Workdir
USER root
RUN mkdir /data && mkdir /refdata && chown mambauser -R /data && chown mambauser -R /refdata
WORKDIR /data

USER mambauser

# reference data mount point
ENV GTDBTK_DATA_PATH=/refdata

# Entrypoint
CMD ["/bin/bash", "-c"]
