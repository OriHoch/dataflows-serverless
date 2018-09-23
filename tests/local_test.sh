#!/usr/bin/env bash

test_output_data() {
    ! diff tests/data/ tests/expected_data/ && echo Unexpected output data && exit 1
}

if [ "${1}" == "--without-serverless" ]; then
    echo "Running without serverless"
    time python3 tests/flow.py
elif [ "${1}" == "--local-serverless" ]; then
    echo "Running with local serverless"
    time ./local_runner.sh tests/flow.py 10 $TEMPDIR
elif [ "${1}" == "--k8s-serverless" ]; then
    echo "Running with k8s serverless"
    time python3 tests/flow.py --serverless --secondaries=5 --output-datadir=tests/data
fi

test_output_data
rm -rf tests/data

echo Great Success
exit 0
