FROM continuumio/miniconda3

LABEL maintainer="Microbiome Informatics Team www.ebi.ac.uk/metagenomics"

LABEL base_image="continuumio/miniconda3"
LABEL version="1"
LABEL software="defense-finder"
LABEL software.version="1.2.0"

# Install hmmer using conda
RUN conda install -c bioconda hmmer && conda clean -afy

# Add the conda environment to the PATH
ENV PATH=/opt/conda/bin:${PATH}

# Install mdmparis-defense-finder using pip
RUN pip install mdmparis-defense-finder
