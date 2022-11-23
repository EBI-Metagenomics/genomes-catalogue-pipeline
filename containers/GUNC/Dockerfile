FROM ubuntu:latest

LABEL software="gunc"
LABEL software.version="1.0.3"
LABEL description="Genome UNClutterer (GUNC) is a tool for detection of chimerism and contamination in prokaryotic genomes resulting from mis-binning of genomic contigs from unrelated lineages"
LABEL website="https://github.com/grp-bork/gunc"
LABEL license="GPLv3"

RUN apt update && \
    apt upgrade -y && \
    apt install -y \
        python3 \
        python3-pip \
        wget

WORKDIR /usr/local/bin

# Install Diamond 2.0.4
ARG diamondVer=2.0.4
RUN wget https://github.com/bbuchfink/diamond/releases/download/v$diamondVer/diamond-linux64.tar.gz && \
    tar zxf diamond-linux64.tar.gz && \
    rm diamond-linux64.tar.gz

# Install Prodigal
ARG prodigalVer=2.6.3
RUN wget -O prodigal https://github.com/hyattpd/Prodigal/releases/download/v$prodigalVer/prodigal.linux && \
    chmod a+x prodigal

# Install GUNC
RUN pip3 install gunc

# Workdir
RUN mkdir /data
WORKDIR /data

COPY filter.sh /tools/
RUN chmod a+x /tools/*

ENV PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/tools

# Entrypoint
CMD ["/bin/bash", "-c"]