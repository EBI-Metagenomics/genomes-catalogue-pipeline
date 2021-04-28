FROM continuumio/miniconda3

LABEL maintainer="Ekaterina Sakharova <kates@ebi.ac.uk>"

WORKDIR /app

# Create the environment:
COPY env.yml .
RUN conda env create -f env.yml

# Make RUN commands use the new environment:
RUN conda activate genomes-pipeline

#SHELL ["conda", "run", "-n", "genomes-pipeline", "/bin/bash", "-c"]

# The code to run when container is started:
# COPY run.py .
# ENTRYPOINT ["conda", "run", "--no-capture-output", "-n", "myenv", "python", "run.py"]

# Custom scripts
COPY custom_scripts/* /tools/

RUN chmod a+x /tools/*

ENV PATH="/samtools/bin:/tools:${PATH}"