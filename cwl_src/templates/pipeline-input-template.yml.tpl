############################################
### THIS IS A TEMPLATE, ADJUST AS NEEDED ###
############################################

# no gtdbtk
skip_gtdbtk_step: True
skip_drep_step: False

# common input
mmseqs_limit_i:
  - 1.0
  - 0.95
  - 0.50
mmseq_limit_annotation: 0.9
mmseqs_limit_c: 0.8

# GUNC
gunc_db_path:
  class: File
  path: <replace-with-path>/gunc_db_2.0.4.dmnd

# IPS
interproscan_databases:
  class: Directory
  path: <replace-with-path>/ips/data
chunk_size_ips: 10000

# EggNOG
chunk_size_eggnog: 100000
db_diamond_eggnog:
  class: File
  path: <replace-with-path>/eggnog/data/eggnog_proteins.dmnd
db_eggnog:
  class: File
  path: <replace-with-path>/eggnog/data/eggnog.db
data_dir_eggnog:
  class: Directory
  path: <replace-with-path>/eggnog/data/

# GTDB-Tk
gtdbtk_data:
  class: Directory
  path: <replace-with-path>/release202

# rRNA
cm_models:
  class: Directory
  path: <replace-with-path>/rfams_cms

kegg_db:
  class: File
  path: <replace-with-path>/kegg_classes.tsv

geo_metadata:
  class: File
  path: <replace-with-path>/continent_countries.csv

# ncRNA
claninfo_ncrna:
  class: File
  path: <replace-with-path>/ncrna_cms/Rfam.clanin

models_ncrna:
  class: File
  path: <replace-with-path>/ncrna_cms/Rfam.cm

#  genomes_ena: Directory?
#  ena_csv: File?
#  genomes_ncbi: Directory?
#
#  max_accession_mgyg: int
#  min_accession_mgyg: int
#  ftp_name_catalogue: string
#  ftp_version_catalogue: string
#  biom