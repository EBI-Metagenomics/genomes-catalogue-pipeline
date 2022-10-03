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
   -r      run with Toil
EOF
}

export REFDATA="/hps/nobackup/rdf/metagenomics/service-team/production/ref-dbs/genomes-pipeline/release202"
export TOIL=False

while getopts ho:p:l:n:q:y:j:a:z:t:r: option; do
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
		r)
		    TOIL=${OPTARG}
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


if [ "${TOIL}" == "True" ]; then

    echo "Running ${DIRNAME} gtdb with ${YML}/gtdbtk.yml with Toil"
    bsub \
         -J "${JOB}.${DIRNAME}.run" \
         -e "${LOGS}"/${JOB}.err \
         -o "${LOGS}"/${JOB}.out \
         bash "${P}"/cluster/codon/Toil/run-toil.sh \
            -n "gtdbtk" \
            -q "${QUEUE}" \
            -b "True" \
            -p "${P}" \
            -o "${OUT}" \
            -m "${MEM}" \
            -c "${P}"/cwl/sub-wfs/5_gtdb/gtdbtk.cwl \
            -y "${YML}"/gtdbtk.yml
else
    echo "Running ${DIRNAME} gtdb with ${YML}/gtdbtk.yml"
    bsub \
         -J "${JOB}.${DIRNAME}.run" \
         -e "${LOGS}"/${JOB}.err \
         -o "${LOGS}"/${JOB}.out \
         -M "${MEM}" \
         -n "${THREADS}" \
         -q "${QUEUE}"  \
         bash "${P}"/cluster/codon/run-cwltool.sh \
            -d False \
            -p "${P}" \
            -o "${OUT}" \
            -n "gtdbtk" \
            -c "${P}"/cwl/sub-wfs/5_gtdb/gtdbtk.cwl \
            -y "${YML}"/gtdbtk.yml
fi