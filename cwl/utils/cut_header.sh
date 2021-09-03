#!/bin/bash

while getopts :i: option; do
	case "${option}" in
		i) INPUT=${OPTARG};;
	esac
done

cat ${INPUT} | tr '-' ' '