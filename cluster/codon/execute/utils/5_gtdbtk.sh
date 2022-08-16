#!/bin/bash

usage()
{
cat << EOF
usage: $0 options
Run genomes-pipeline mash2nwk step
OPTIONS:
   -o      Path to general output catalogue directory
   -p      Path to installed pipeline location
   -l      Path to logs folder
   -n      Catalogue name
   -q      LSF queue to run in
   -y      Path to folder to save yml file
   -j      LSF step Job name to submit
   -a      Path to directory with fasta.fna cluster representatives (filtered)
   -z      memory in Gb
   -t      number of threads
EOF
}

export REFDATA="/hps/nobackup/rdf/metagenomics/service-team/production/ref-dbs/genomes-pipeline/release202"

while getopts ho:p:l:n:q:y:j:a:z:t: option; do
	case "${option}" in
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
		a)
		    REPS_FA=${OPTARG}
		    ;;
        z)
		    MEM=${OPTARG}
		    ;;
		t)
		    THREADS=${OPTARG}
		    ;;
		?)
            usage
            exit
            ;;
	esac
done

echo "Create gtdb-tk yml"
echo \
"
drep_folder:
  class: Directory
  path: ${REPS_FA}
gtdb_outfolder: gtdbtk-outdir
refdata:
  class: Directory
  path: ${REFDATA}
" > "${YML}"/gtdbtk.yml

echo "Running ${DIRNAME} gtdb with ${YML}/gtdbtk.yml"

bsub \
     -J "${JOB}.${DIRNAME}.run" \
     -q "${QUEUE}" \
     -e "${LOGS}"/gtdbtk.err \
     -o "${LOGS}"/gtdbtk.out \
     -M "${MEM}" \
     -n "${THREADS}" \
     bash "${P}"/cluster/codon/run-cwltool.sh \
        -d False \
        -p "${P}" \
        -o "${OUT}" \
        -n "gtdbtk" \
        -c "${P}"/cwl/sub-wfs/5_gtdb/gtdbtk.cwl \
        -y "${YML}"/gtdbtk.yml