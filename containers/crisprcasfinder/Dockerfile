# Dockerfile for CRISPRCasFinder

FROM ubuntu:20.04

LABEL software="CRISPRCasFinder"
LABEL software.version="4.3.2"
LABEL description="CRISPRCasFinder is an updated, improved, and integrated version of CRISPRFinder and CasFinder."
LABEL website="https://github.com/dcouvin/CRISPRCasFinder/"
LABEL license="https://github.com/dcouvin/CRISPRCasFinder/blob/master/COPYRIGHT"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && \
    apt install -y --no-install-recommends \
        build-essential \
        wget \
        unzip \
        curl \
        git \
        default-jre \
        python \
        parallel \
        cpanminus \
        hmmer \
        emboss \
        emboss-lib \
        ncbi-blast+ \
        bioperl \
        bioperl-run \
        python3-biopython \
        libdatetime-perl \
        libxml-simple-perl \
        libdigest-md5-perl \
        prodigal \
        original-awk \
        dateutils \
        procps \
        pcregrep \
        sed \
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/*

# perl deps
RUN cpanm -n Unix::Sysexits
RUN cpanm -n Try::Tiny
RUN cpanm -n Test::Most
RUN cpanm -n JSON::Parse
RUN cpanm -n Class::Struct
RUN cpanm -n Bio::DB::Fasta
RUN cpanm -n File::Copy
RUN cpanm -n Bio::Seq Bio::SeqIO
RUN cpanm -n Bio::Tools::Run::Alignment::Muscle

# get CRISPRCasFinder
ENV crisprcasfinderVer="4.3.2"
WORKDIR /opt
RUN wget -q -O CRISPRCasFinder.zip 'https://github.com/dcouvin/CRISPRCasFinder/archive/refs/tags/release-4.3.2.zip' && \
    unzip CRISPRCasFinder.zip && \
    mv CRISPRCasFinder-release-${crisprcasfinderVer} CRISPRCasFinder && \
    mkdir CRISPRCasFinder/src CRISPRCasFinder/bin && \
    ln -s /opt/CRISPRCasFinder/CRISPRCasFinder.pl /usr/local/bin/ && \
    rm CRISPRCasFinder.zip

# get muscle v.5.1.0
WORKDIR /opt/CRISPRCasFinder/src
RUN wget -q https://github.com/rcedgar/muscle/releases/download/5.1.0/muscle5.1.linux_intel64 && \
    cp muscle5.1.linux_intel64 /usr/local/bin/muscle && \
    rm muscle5.1.linux_intel64

WORKDIR /usr/local/bin
RUN chmod +x /usr/local/bin/*

# build vmatch
ENV vmatchVer="2.3.0"
WORKDIR /opt/CRISPRCasFinder/src
RUN wget -q http://vmatch.de/distributions/vmatch-${vmatchVer}-Linux_x86_64-64bit.tar.gz && \
    tar -zxf vmatch-${vmatchVer}-Linux_x86_64-64bit.tar.gz && \
    gcc -Wall -Werror -fPIC -O3 -shared vmatch-${vmatchVer}-Linux_x86_64-64bit/SELECT/sel392.c -o /opt/CRISPRCasFinder/sel392v2.so && \
    cp vmatch-${vmatchVer}-Linux_x86_64-64bit/vmatch /usr/local/bin/vmatch && \
    cp vmatch-${vmatchVer}-Linux_x86_64-64bit/mkvtree /usr/local/bin/mkvtree && \
    cp vmatch-${vmatchVer}-Linux_x86_64-64bit/vsubseqselect /usr/local/bin/vsubseqselect && \
    rm -rf vmatch-${vmatchVer}-Linux_x86_64-64bit*

# get MacSyFinder
ENV macsyfinderVer="2.0"
WORKDIR /opt

RUN wget -O macsyfinder-${macsyfinderVer}.tar.gz -q https://github.com/gem-pasteur/macsyfinder/archive/refs/tags/v${macsyfinderVer}.tar.gz && \
    tar -xzf macsyfinder-${macsyfinderVer}.tar.gz && \
    rm macsyfinder-${macsyfinderVer}.tar.gz && \
    ln -s /opt/macsyfinder-${macsyfinderVer}/bin/macsyfinder /usr/local/bin/

ENV MACSY_HOME=/opt/macsyfinder-${macsyfinderVer}/

# for singularity compatibility
ENV LC_ALL=C

RUN mkdir /data
WORKDIR /data

CMD ["/bin/bash", "-c"]
