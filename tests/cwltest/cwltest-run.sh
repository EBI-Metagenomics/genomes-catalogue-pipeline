#!/bin/bash


# tools
for i in $(find tools -name "*tests.yml"); do
    echo "Running: ${i}"
    cwltest --test ${i} --verbose --tool cwltool -- --enable-dev
done



