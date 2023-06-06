FROM quay.io/biocontainers/gtdbtk:2.3.0--pyhdfd78af_2

LABEL software="GTDB-Tk"
LABEL software.version="2.3.0"
LABEL description="A toolkit for assigning objective taxonomic classifications to bacterial and archaeal genomes."
LABEL website="https://github.com/Ecogenomics/GTDBTk"
LABEL license="GPLv3"

# Workdir
RUN mkdir /data
WORKDIR /data

# reference data mount point
ENV GTDBTK_DATA_PATH=/refdata

ENV LC_ALL=C

# Entrypoint
CMD ["/bin/bash", "-c"]
