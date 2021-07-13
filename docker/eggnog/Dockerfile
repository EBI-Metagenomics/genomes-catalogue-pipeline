FROM alpine:3.7

LABEL Maintainer="Ekaterina Sakharova <kates@ebi.ac.uk>"

########################################################################
# Dockerfile Version:   19.03.1
# Software:             eggNOG
# Software Version:     2.1.3
# Description:          functional annotation of novel sequences
########################################################################

ENV VERSION=2.1.3
ENV VERSION_DIAMOND=0.9.31

RUN apk add --no-cache bash git build-base zlib-dev python

# install diamond

RUN wget https://github.com/bbuchfink/diamond/archive/refs/tags/v$VERSION_DIAMOND.tar.gz  && \
    tar -xzf v$VERSION_DIAMOND.tar.gz && \
    cd diamond-$VERSION_DIAMOND && bash build_simple.sh

ENV PATH="/diamond-$VERSION_DIAMOND:${PATH}"

# eggnog
RUN wget https://github.com/eggnogdb/eggnog-mapper/archive/$VERSION.tar.gz && \
    tar -xzf $VERSION.tar.gz

ENV PATH="/eggnog-mapper-$VERSION/eggnogmapper:/eggnog-mapper-$VERSION:${PATH}"

RUN rm /eggnog-mapper-$VERSION/bin/diamond && \
    ln -s /diamond-$VERSION_DIAMOND/diamond /eggnog-mapper-$VERSION/bin/diamond

CMD ["emapper.py"]