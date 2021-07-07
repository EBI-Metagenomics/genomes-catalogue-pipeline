FROM ubuntu:latest

LABEL software="Prokka"
LABEL software.version="1.14.6"
LABEL description="Prokka is a software tool to annotate bacterial, archaeal and viral genomes quickly and produce standards-compliant output files"
LABEL website="https://github.com/tseemann/prokka"
LABEL license="GPLv3"

# Deps
ARG DEBIAN_FRONTEND=noninteractive
RUN apt update && \
    apt upgrade -y && \
    apt install -y \
        libdatetime-perl \
        libxml-simple-perl \
        libdigest-md5-perl \
        libbio-searchio-hmmer-perl \
        git \
        default-jre \
        bioperl \
        hmmer \
        wget
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
    
# Workdir
RUN mkdir /data
WORKDIR /data

ENV PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/prokka/bin

# Entrypoint
CMD ["/bin/bash", "-c"]
