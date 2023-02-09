#!/bin/bash

set -e

export OUTDIR=result

CWL=""
YML=""

while getopts :o:n:y:c:p:d: option; do
    case "${option}" in
    o) OUTDIR=${OPTARG} ;;
    n) NAME=${OPTARG} ;;
    y) YML=${OPTARG} ;;
    c) CWL=${OPTARG} ;;
    d) DEBUG=${OPTARG} ;;
    p) PIPELINE_DIRECTORY=${OPTARG} ;;
    *)
        echo "Invalid usage"
        exit 1
        ;;
    esac
done

. "${PIPELINE_DIRECTORY}/.gpenv"

if [ "${DEBUG}" == "True" ]; then
    cwltool \
        --debug \
        --leave-tmpdir \
        --singularity \
        --preserve-entire-environment \
        --leave-container \
        --outdir "${OUTDIR}"/"${NAME}" \
        "${CWL}" "${YML}"
else
    cwltool \
        --singularity \
        --preserve-entire-environment \
        --leave-container \
        --outdir "${OUTDIR}"/"${NAME}" \
        "${CWL}" "${YML}"
fi
