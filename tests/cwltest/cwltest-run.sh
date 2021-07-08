#!/bin/bash

# tools
echo "TOOLS"
for i in $(find tools -name "*tests.yml"); do
    echo "Running: ${i}"
    cwltest --test ${i} --verbose --tool cwltool -- --enable-dev
done

# utils
echo "UTILS"
for i in $(find utils -name "*tests.yml"); do
    echo "Running: ${i}"
    cwltest --test ${i} --verbose --tool cwltool -- --enable-dev
done