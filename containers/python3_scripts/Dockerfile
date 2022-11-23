FROM python:3.7.9-slim-buster

LABEL maintainer="Microbiome Informatics Team www.ebi.ac.uk/metagenomics"

RUN apt-get update && rm -rf /var/lib/apt/lists/*

RUN /usr/local/bin/python -m pip install --upgrade pip && pip install --no-cache-dir -q biopython

COPY requirements.txt /
RUN pip install -r /requirements.txt

COPY checkm2csv.py \
     classify_folders.py \
     classify_dereplicated.py \
     choose_files_post_processing.py \
     create_final_folder.py \
     generate_gunc_report.py \
     filter_drep_genomes.py \
     ncrna2gff.py \
     phylo_tree_generator.py \
     split_drep.py \
     translate_genes.py \
     split_to_chunks.py \
     unite_ena_ncbi.py \
/tools/

RUN chmod a+x /tools/*

ENV PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/tools