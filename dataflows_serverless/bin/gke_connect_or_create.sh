#!/usr/bin/env bash

GOOGLE_PROJECT_ID="${1}"
ZONE="${2:-us-central1-a}"
CLUSTER_NAME="${3:-dataflows}"
NAMESPACE="${5:-dataflows}"
DISK_SIZE="${5}"
NUM_NODES="${6}"

[ "${GOOGLE_PROJECT_ID}" == "" ] && echo Usage: '$(dataflows_serverless_bin)/gke_connect_or_create.sh'\
                                    '<GOOGLE_PROJECT_ID> [ZONE:us-central1-a] [CLUSTER_NAME:dataflows]' \
                                    '[NAMESPACE:dataflows]' \
                                    '[DISK_SIZE:10] [NUM_NODES:2]' && exit 1

if gcloud --format=none --project=$GOOGLE_PROJECT_ID container clusters get-credentials $CLUSTER_NAME --zone=$ZONE; then
    [ "${DISK_SIZE}${NUM_NODES}" != "" ] && echo warning: DISK_SIZE and NUM_NODES arguments were ignored because cluster already exists
    echo Successfully connected to existing cluster ${CLUSTER_NAME} in Google project ${GOOGLE_PROJECT_ID}, zone ${ZONE}
else
    ! gcloud --project=$GOOGLE_PROJECT_ID container clusters create $CLUSTER_NAME \
        --disk-size=${DISK_SIZE:-10} --num-nodes=${NUM_NODES:-2} --zone=$ZONE \
        && exit 1
    echo Successfully created cluster ${CLUSTER_NAME} in Google project ${GOOGLE_PROJECT_ID}, zone ${ZONE}
fi

kubectl create ns $NAMESPACE 2>/dev/null

! kubectl config set-context $(kubectl config current-context) --namespace=$NAMESPACE && exit 1

echo Great Success, connected to a cluster with the following nodes:
! kubectl get nodes && exit 1
exit 0
