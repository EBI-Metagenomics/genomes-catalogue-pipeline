FROM ubuntu:latest

LABEL Maintainer="Microbiome Informatics Team www.ebi.ac.uk/metagenomics"
LABEL software="eggNOG"
LABEL software.version="2.1.3"
LABEL description="EggNOG-mapper is a tool for fast functional annotation of novel sequences."
LABEL website="https://github.com/eggnogdb/eggnog-mapper"
LABEL license="GPL3"


ENV VERSION=2.1.3
ENV VERSION_DIAMOND=2.0.11

# deps
ARG DEBIAN_FRONTEND=noninteractive
RUN apt update && \
    apt upgrade -y && \
    apt install -y \
        git \
        wget \
        python3 \
        python3-dev \
        python3-numpy \
        cython3 \
        zlib1g-dev \
        python3-pip \
        python3-setuptools

# install diamond
WORKDIR /usr/local/bin/
RUN wget -q https://github.com/bbuchfink/diamond/releases/download/v${VERSION_DIAMOND}/diamond-linux64.tar.gz && \
    tar -xzf diamond-linux64.tar.gz && \
    rm -rf diamond-linux64.tar.gz && \
    chmod a+x diamond

# install eggnog
WORKDIR /opt
RUN wget -q https://github.com/eggnogdb/eggnog-mapper/archive/$VERSION.tar.gz && \
    tar -xzf $VERSION.tar.gz && \
    rm -rf $VERSION.tar.gz && \
    cd eggnog-mapper-$VERSION && \
    python3 setup.py install

ENV PATH="/opt/eggnog-mapper-$VERSION/eggnogmapper:/opt/eggnog-mapper-$VERSION:${PATH}"


CMD ["emapper.py"]