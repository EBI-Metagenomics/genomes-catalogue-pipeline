FROM continuumio/miniconda3

LABEL maintainer="Ekaterina Sakharova <kates@ebi.ac.uk>"

RUN conda create -n env python=3.6
RUN echo "source activate env" > ~/.bashrc
ENV PATH /opt/conda/envs/env/bin:$PATH



#WORKDIR /app

# Create the environment:
#COPY env.yml .
#RUN conda env create -f env.yml

# Make RUN commands use the new environment:
#SHELL ["conda", "run", "-n", "genomes-pipeline", "/bin/bash", "-c"]

# The code to run when container is started:
# COPY run.py .
# ENTRYPOINT ["conda", "run", "--no-capture-output", "-n", "myenv", "python", "run.py"]

# Custom scripts
#COPY custom_scripts/* /tools/
#RUN chmod a+x /tools/*
#ENV PATH="/samtools/bin:/tools:${PATH}"