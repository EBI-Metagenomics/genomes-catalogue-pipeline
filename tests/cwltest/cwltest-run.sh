#!/bin/bash

# tools
echo "TOOLS"
for TEST_TOOL in $(find tools -name "*tests.yml"); do
    echo "Running: ${TEST_TOOL}"
    cwltest --test "${TEST_TOOL}" --verbose --tool cwltool -- --enable-dev
done

# utils
echo "UTILS"
for TEST_UTIL in $(find utils -name "*tests.yml"); do
    echo "Running: ${TEST_UTIL}"
    cwltest --test "${TEST_UTIL}" --verbose --tool cwltool -- --enable-dev
done