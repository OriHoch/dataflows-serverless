#!/usr/bin/env bash

[ "${DATAFLOWS_WORKDIR}" == "" ] && echo missing DATAFLOWS_WORKDIR environment variable && exit 1
[ "${FLOW_FILE}" == "" ] && echo missing FLOW_FILE environment variable && exit 1
[ "${DATAFLOWS_SERVERLESS_ROLE}" == "" ] && echo missing DATAFLOWS_SERVERLESS_ROLE environment variable && exit 1
[ "${SECONDARIES}" == "" ] && echo missing SECONDARIES environment variable && exit 1

while ! [ -e "${DATAFLOWS_WORKDIR}/code/${FLOW_FILE}" ]; do
    echo waiting for flow file: "${DATAFLOWS_WORKDIR}/code/${FLOW_FILE}"
    sleep 1
done

cd "${DATAFLOWS_WORKDIR}/code"

if [ "${DATAFLOWS_SERVERLESS_ROLE}" == "primary" ]; then
    exec python3 "${FLOW_FILE}" --serverless --secondaries=$SECONDARIES --primary "--workdir=${DATAFLOWS_WORKDIR}"

elif [ "${DATAFLOWS_SERVERLESS_ROLE}" == "secondary" ]; then
    [ "${SECONDARY}" == "" ] && echo missing SECONDARY environment variable && exit 1
    exec python3 "${FLOW_FILE}" --serverless --secondaries=$SECONDARIES --secondary=$SECONDARY "--workdir=${DATAFLOWS_WORKDIR}"

else
    echo unexpected role "${DATAFLOWS_SERVERLESS_ROLE}"
    exit 1

fi
