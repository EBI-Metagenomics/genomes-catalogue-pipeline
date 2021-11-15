#!/bin/bash

set -e

usage()
{
cat << EOF
usage: $0 options

Remove overlaps from cmcsan result

OPTIONS:
   -i      Input cmscan tblout [REQUIRED]
   -o      Output cmscan deoverlapped [REQUIRED]
EOF
}


while getopts "i:o:" OPTION
do
     case ${OPTION} in
         i)
             INPUT=${OPTARG}
             ;;
         o)
             OUTPUT=${OPTARG}
             ;;
         ?)
             usage
             exit
             ;;
     esac
done


grep -v " = " ${INPUT} > ${OUTPUT}
