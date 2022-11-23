FROM biocontainers/bioperl:v1.7.2-3-deb_cv1

LABEL software="GTDB-Tk taxonomy dump"
LABEL software.version="1.0"
LABEL description="Convert the GTDB taxonomy file to a Kraken files."
LABEL website="https://gist.github.com/lskatz/7403e9693a49cbb60c4a1cb2ce5c3475"
# TODO: contact the author and find out.
# LABEL license="GPLv3"

WORKDIR /opt

COPY gtdbToTaxonomy.pl /opt/gtdbToTaxonomy.pl

ENV PATH="/opt/gtdbToTaxonomy.pl:$PATH"

CMD ["/bin/bash", "-c"]
