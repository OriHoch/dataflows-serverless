#!/usr/bin/env bash

[ "$1" == "" ] &&\
    echo 'usage: ./local_runner.sh <FLOW_FILE> <NUM_SECONDARIES> [WORKDIR]' &&\
    exit 1

FLOW_FILE="${1}"
SECONDARIES="${2}"
WORKDIR="${3}"

if [ "${WORKDIR}" == "" ]; then
    TEMPDIR=`mktemp -d`
    WORKDIR="${TEMPDIR}"
    echo "WORKDIR=$WORKDIR"
else
    TEMPDIR=""
fi

cleanup() {
    rm -rf ${WORKDIR}/primary
    rm -rf ${WORKDIR}/secondary
}

start_primary() {
    cleanup
    mkdir -p "${WORKDIR}"
    python "${FLOW_FILE}" --serverless --primary --secondaries=$SECONDARIES "--workdir=${WORKDIR}"
}

start_secondary() {
    python tests/flow.py --serverless --secondary=$1 --secondaries=$SECONDARIES "--workdir=${WORKDIR}"
}

cleanup

PRIMARY_RES=1

trap 'if [ "${PRIMARY_RES}" != "0" ]; then kill 0; fi' EXIT

for SECONDARY in $(seq 0 `expr $SECONDARIES - 1`); do
    start_secondary $SECONDARY &
done

start_primary
PRIMARY_RES=$?

if [ "${TEMPDIR}" != "" ]; then
    rm -rf "${TEMPDIR}"
fi

exit "${PRIMARY_RES}"
