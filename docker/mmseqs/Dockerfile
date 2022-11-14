FROM continuumio/miniconda3

LABEL maintainer="Microbiome Informatics Team www.ebi.ac.uk/metagenomics"

LABEL base_image="continuumio/miniconda3"
LABEL version="1"
LABEL software="mmseqs"
LABEL software.version="13.45111"

ENV VERSION=13.45111

RUN conda install -c bioconda mmseqs2=${VERSION} --yes --freeze-installed && conda clean -afy

COPY mmseqs_wf_without_symlinks.sh /tools/mmseqs_wf.sh
RUN chmod a+x /tools/*

ENV PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/tools
ENV PATH=/opt/conda/bin:${PATH}

CMD mmseqs_wf.sh