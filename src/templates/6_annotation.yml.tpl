############################################
### THIS IS A TEMPLATE, ADJUST AS NEEDED ###
############################################

interproscan_databases:
  class: Directory
  path: <replace-with-path>/interproscan/data
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

cm_models:
  class: Directory
  path: <replace-with-path>/rfams_cms
