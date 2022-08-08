#!/bin/bash

export GEO="/hps/nobackup/rdf/metagenomics/service-team/production/ref-dbs/genomes-pipeline/continent_countries.csv"

while getopts :o:p:l:n:q:y:v:i:g: option; do
	case "${option}" in
		o) OUT=${OPTARG};;
		p) P=${OPTARG};;
		l) LOGS=${OPTARG};;
		n) DIRNAME=${OPTARG};;
		q) QUEUE=${OPTARG};;
		y) YML=${OPTARG};;
		v) VERSION=${OPTARG};;
		i) INTERMEDIATE_FILES=${OPTARG};;
		g) GTDB_TAXONOMY=${OPTARG};;
	esac
done

echo "Creating yml"
export YML_FILE=${YML}/metadata.yml
echo \
"
extra_weights_table:
  class: File
  path: ${INTERMEDIATE_FILES}/extra_weight_table.txt
checkm_results_table:
  class: File
  path: ${INTERMEDIATE_FILES}/renamed_download.csv
rrna_dir:
  class: Directory
  path:
naming_table:
  class: File
  path: ${INTERMEDIATE_FILES}/names.tsv
clusters_split:
  class: File
  path: ${INTERMEDIATE_FILES}/clusters_split.txt
metadata_outname: genomes-all_metadata.tsv
ftp_name_catalogue: ${DIRNAME}
ftp_version_catalogue: ${VERSION}
geo_file:
  class: File
  path: ${GEO}
gunc_failed_genomes:
  class: File
  path:
gtdb_taxonomy:
  class: File
  path: ${GTDB_TAXONOMY}
"

export CWL=${P}/cwl/sub-wfs/5_gtdb/metadata_and_phylo_tree.cwl
