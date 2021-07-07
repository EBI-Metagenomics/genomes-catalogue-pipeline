FROM continuumio/miniconda3

LABEL software="eggnog-mapper"
LABEL software.version="2.1.3"
LABEL description="EggNOG-mapper is a tool for fast functional annotation of novel sequences. It uses precomputed orthologous groups and phylogenies from the eggNOG database (http://eggnog5.embl.de) to transfer functional information from fine-grained orthologs only."
LABEL website="https://github.com/eggnogdb/eggnog-mapper"
LABEL license="GPLv3"

RUN conda install -c bioconda eggnog-mapper && conda clean -afy

# Workdir
RUN mkdir /data
WORKDIR /data

# Entrypoint
CMD ["/bin/bash", "-c"]
