FROM continuumio/miniconda3

LABEL Maintainer="Microbiome Informatics Team www.ebi.ac.uk/metagenomics"
################################################################################
# Dockerfile Version:   19.03.1
# Software:             Detect rRNA with cmsearch
# Software Version:     1.1.2
# Description:          Script will use INFERNAL and tRNAScan
#                       to detect the bacterial 5S, 16S, 23S rRNA and tRNA genes.
#################################################################################

RUN conda install -c bioconda trnascan-se biopython --yes --freeze-installed && conda clean -afy
RUN mkdir /tools

COPY cmsearch-deoverlap.pl \
     parse_rRNA-bacteria.py \
     parse_tRNA.py \
     rRNA2seq.py \
     rna-detect.sh \
     /tools/

ENV PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/conda/bin:/usr/bin/env:/tools
RUN chmod a+x /tools/*
