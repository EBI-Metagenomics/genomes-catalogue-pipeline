#!/bin/bash

usage()
{
cat << EOF
usage: $0 options
Run genomes-pipeline post-processing steps: kegg, cog, ncRNA, populate GFF, generate genome.json
OPTIONS:
   -o      Path to general output catalogue directory
   -p      Path to installed pipeline location
   -l      Path to logs folder
   -n      Catalogue name
   -q      LSF queue to run in
   -y      Path to folder to save yml file
   -j      LSF step Job name to submit
   -c      LSF job condition
   -b      Catalogue biom
   -m      GTDB-Tk metadata
   -a      Path to directory with EggNOG and InterProScan separated files
EOF
}

while getopts ho:p:l:n:q:y:j:c:b:m:a: option; do
	case "$option" in
	    h)
             usage
             exit 1
             ;;
		o)
		    OUT=${OPTARG}
		    ;;
		p)
		    P=${OPTARG}
		    ;;
		l)
		    LOGS=${OPTARG}
		    ;;
		n)
		    DIRNAME=${OPTARG}
		    ;;
		q)
		    QUEUE=${OPTARG}
		    ;;
		y)
		    YML=${OPTARG}
		    ;;
		j)
		    JOB=${OPTARG}
		    ;;
		c)
		    CONDITION_JOB=${OPTARG}
		    ;;
        b)
            BIOM=${OPTARG}
		    ;;
		m)
		    METADATA=${OPTARG}
		    ;;
		a)
		    ANNOTATIONS=${OPTARG}
		    ;;
		?)
		    usage
            exit
            ;;
	esac
done

echo "Generating yml file"
export YML_FILE=${YML}/post-processing.yml
cp ${P}/cluster/codon/execute/utils/8_post_processing.yml ${YML_FILE}
echo \
"
biom: ${BIOM}
metadata:
  class: File
  path: ${METADATA}
annotations:
" > ${YML_FILE}

ls ${ANNOTATIONS} | grep 'MGYG' > list_annotations.txt
for i in $(cat list_annotations.txt); do
    echo \
"
  - class: File
    path: ${ANNOTATIONS}/${i}
" >> ${YML_FILE}
done
rm list_annotations.txt

echo \
"
clusters:
" >> ${YML_FILE}

for i in $(ls ${OUT}/sg); do
    NAME="$(basename -- ${i} | tr '_' '\t' | cut -f1)"
    echo \
"
  - class: Directory
    path: ${OUT}/sg/${i}/${NAME}
" >> ${YML_FILE}
done

for i in $(ls ${OUT}/pg); do
    NAME="$(basename -- ${i} | tr '_' '\t' | cut -f1)"
    echo \
"
  - class: Directory
    path: ${OUT}/pg/${i}/${NAME}
" >> ${YML_FILE}
done

export CWL=${P}/cwl/sub-wfs/wf-6-post-processing.cwl
echo "Submitting cluster post-processing"
bsub \
    -J "${JOB}.${DIRNAME}" \
    -w "${CONDITION_JOB}"\
    -q "${QUEUE}" \
    -e "${LOGS}"/post-processing.err \
    -o "${LOGS}"/post-processing.out \
    bash ${P}/cluster/codon/run-cwltool.sh \
        -d False \
        -p ${P} \
        -o ${OUT} \
        -n "${DIRNAME}_metadata" \
        -c ${CWL} \
        -y ${YML_FILE}