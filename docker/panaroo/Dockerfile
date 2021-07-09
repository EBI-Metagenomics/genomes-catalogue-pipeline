FROM ubuntu:latest

LABEL software="panaroo"
LABEL software.version="1.2.7"
LABEL description="A Bacterial Pangenome Analysis Pipeline."
LABEL website="https://github.com/gtonkinhill/panaroo"
LABEL license="MIT"

# Deps
ARG DEBIAN_FRONTEND=noninteractive
RUN apt update && \
    apt upgrade -y && \
    apt install -y \
        mafft \
        cd-hit \
        prank \
        mash \
        python3 \
        python3-pip \
        python3-biopython \
        python3-numpy \
        python3-networkx \
        python3-gffutils \
        python3-edlib \
        python3-joblib \
        libdatetime-perl \
        libxml-simple-perl \
        libdigest-md5-perl \
        libbio-searchio-hmmer-perl \
        git \
        default-jre \
        bioperl \
        hmmer \
        wget

RUN pip install tdqm
RUN cpan Bio::Perl

# Install Prokka from source
WORKDIR /opt
RUN git clone https://github.com/tseemann/prokka.git && \
    /opt/prokka/bin/prokka --setupdb

# Adding tbl2asn
WORKDIR /usr/local/bin
RUN wget -q -O tbl2asn.gz https://ftp.ncbi.nih.gov/toolbox/ncbi_tools/converters/by_program/tbl2asn/linux64.tbl2asn.gz && \
    gunzip tbl2asn.gz && \
    chmod +x tbl2asn

# Install panaroo
WORKDIR /opt
RUN git clone https://github.com/gtonkinhill/panaroo && \
    cd panaroo && \
    python3 setup.py install

# Workdir
RUN mkdir /data
WORKDIR /data

ENV PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/prokka/bin

# Entrypoint
CMD ["/bin/bash", "-c"]
