FROM r-base:4.1.0

LABEL software="mash2nwk"
LABEL software.version="1.0.0"
LABEL description="Generate Mash distance tree of conspecific genomes"
LABEL website="https://github.com/EBI-Metagenomics/genomes-pipeline"
LABEL license="GPLv3"

RUN install2.r \
        reshape2 \
        fastcluster \
        optparse \
        data.table \
        ape

RUN mkdir /tools
COPY mash2nwk1.R /tools
RUN chmod a+x /tools/*
ENV PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/tools

# Workdir
RUN mkdir /data
WORKDIR /data

# Entrypoint
CMD ["Rscript", "/tools/mash2nwk1.R"]