#!/bin/bash

while getopts :i: option; do
	case "${option}" in
		i) INPUT=${OPTARG};;
	esac
done

python3 convert_json_to_output.py -i ${INPUT} > result
grep -v location result | grep -v path