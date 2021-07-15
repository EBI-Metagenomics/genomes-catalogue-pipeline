FROM ubuntu:latest

LABEL software="InterProScan"
LABEL software.version="5.52-86"
LABEL description="InterProScan is a search engine for InterPro is a database which integrates together predictive information about proteins' function."
LABEL website="https://github.com/ebi-pf-team/interproscan"
LABEL license="Apache 2.0"

# Deps
ARG DEBIAN_FRONTEND=noninteractive
RUN apt update && \
    apt upgrade -y --no-install-recommends && \
    apt install -y \
        default-jre \
        python3 \
        libpcre3-dev \
        cpanminus \
        build-essential \
        wget
RUN cpanm Data::Dumper

# Install IPS
ARG ipsVersion=5.52-86.0
WORKDIR /opt
RUN wget -q ftp://ftp.ebi.ac.uk/pub/software/unix/iprscan/5/${ipsVersion}/interproscan-${ipsVersion}-64-bit.tar.gz && \
    tar pxfz interproscan-${ipsVersion}-64-bit.tar.gz  && \
    rm interproscan-${ipsVersion}-64-bit.tar.gz && \
    rm -rf interproscan-${ipsVersion}/data
    #cd interproscan-${ipsVersion} && \
    #python3 initial_setup.py

RUN ln -s /opt/interproscan-${ipsVersion}/interproscan.sh /usr/local/bin/

# Workdir
RUN mkdir /data
WORKDIR /data

# Entrypoint
CMD ["/bin/bash", "-c"]