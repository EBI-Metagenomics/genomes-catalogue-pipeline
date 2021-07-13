FROM alpine:3.14.0

LABEL Maintainer="Ekaterina Sakharova <kates@ebi.ac.uk>"
LABEL software="eggNOG"
LABEL software.version="2.1.3"
LABEL description="EggNOG-mapper is a tool for fast functional annotation of novel sequences."
LABEL website="https://github.com/eggnogdb/eggnog-mapper"
LABEL license="GPL3"


ENV VERSION=2.1.3
ENV VERSION_DIAMOND=2.0.11

RUN apk add --no-cache \
        bash \
        git \
        build-base \
        zlib-dev \
        python3 \
        python3-dev \
        py3-setuptools \
        py3-numpy \
        cython \
        linux-headers

# install diamond
WORKDIR /usr/local/bin/
RUN wget https://github.com/bbuchfink/diamond/releases/download/v${VERSION_DIAMOND}/diamond-linux64.tar.gz && \
    tar -xzf diamond-linux64.tar.gz && \
    rm -rf diamond-linux64.tar.gz && \
    chmod a+x diamond

# install eggnog
WORKDIR /opt
RUN wget https://github.com/eggnogdb/eggnog-mapper/archive/$VERSION.tar.gz && \
    tar -xzf $VERSION.tar.gz && \
    rm -rf $VERSION.tar.gz && \
    cd eggnog-mapper-$VERSION && \
    python3 setup.py install

ENV PATH="/opt/eggnog-mapper-$VERSION/eggnogmapper:/opt/eggnog-mapper-$VERSION:${PATH}"


CMD ["emapper.py"]