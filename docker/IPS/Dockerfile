FROM ubuntu:latest

LABEL software="InterProScan"
LABEL software.version="5.52-86"
LABEL description="InterProScan is a search engine for InterPro is a database which integrates together predictive information about proteins' function."
LABEL website="https://github.com/ebi-pf-team/interproscan"
LABEL license="Apache 2.0"

# Deps
ARG DEBIAN_FRONTEND=noninteractive
RUN apt update && \
    apt upgrade -y && \
    apt install -y \
        default-jre \
        wget

# Install IPS
ARG ipsVersion=5.52-86.0
WORKDIR /opt
RUN wget -q ftp://ftp.ebi.ac.uk/pub/software/unix/iprscan/5/$ipsVersion/interproscan-$ipsVersion-64-bit.tar.gz && \
    tar --exclude="interproscan-5.52-86.0/data/" -pxfz interproscan-$ipsVersion-64-bit.tar.gz && \
    rm interproscan-$ipsVersion-64-bit.tar.gz

# Workdir
RUN mkdir /data
WORKDIR /data

# Entrypoint
CMD ["/bin/bash", "-c"]
