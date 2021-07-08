FROM continuumio/miniconda3

LABEL software="panaroo"
LABEL software.version="1.2.7"
LABEL description="A Bacterial Pangenome Analysis Pipeline."
LABEL website="https://github.com/gtonkinhill/panaroo"
LABEL license="MIT"

RUN conda install -c conda-forge -c bioconda -c defaults panaroo && conda clean -afy

# Workdir
RUN mkdir /data
WORKDIR /data

# Entrypoint
CMD ["/bin/bash", "-c"]
