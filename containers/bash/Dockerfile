FROM alpine:3.7 as build

LABEL maintainer="Microbiome Informatics Team www.ebi.ac.uk/metagenomics"

RUN apk add --no-cache build-base ncurses-dev bzip2-dev xz-dev zlib-dev

ENV SAMTOOLS_VERSION=1.9

# samtools and bgzip
RUN mkdir /samtools && \
    wget https://github.com/samtools/samtools/releases/download/$SAMTOOLS_VERSION/samtools-$SAMTOOLS_VERSION.tar.bz2 && \
    tar -xjf samtools-$SAMTOOLS_VERSION.tar.bz2 && rm samtools-$SAMTOOLS_VERSION.tar.bz2 && \
    cd samtools-$SAMTOOLS_VERSION && ./configure --prefix=/samtools && make && make install install-htslib



FROM alpine:3.7

RUN apk add --no-cache pigz nodejs coreutils bash zlib bzip2 ncurses  \
    ncurses-dev bzip2-dev xz-dev zlib-dev tar && \
    mkdir /tools && mkdir /samtools

COPY --from=build /samtools /samtools

COPY index_fasta.sh \
     remove_overlaps_cmscan.sh \
    /tools/

RUN chmod a+x /tools/*

ENV PATH="/samtools/bin:/tools:${PATH}"