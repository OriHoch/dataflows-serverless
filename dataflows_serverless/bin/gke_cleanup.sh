#!/usr/bin/env bash

GOOGLE_PROJECT_ID="${1}"
ZONE="${2:-us-central1-a}"
CLUSTER_NAME="${3:-dataflows}"

[ "${GOOGLE_PROJECT_ID}" == "" ] && echo Usage: '$(dataflows_serverless_bin)/gke_cleanup.sh'\
                                    '<GOOGLE_PROJECT_ID> [ZONE:us-central1-a] [CLUSTER_NAME:dataflows]' \
                                    && exit 1

! gcloud --project=$GOOGLE_PROJECT_ID container clusters delete $CLUSTER_NAME --zone=$ZONE \
    && echo failed to delete cluster && exit 1

echo Cluster ${CLUSTER_NAME} on Google project ${GOOGLE_PROJECT_ID} zone ${ZONE} was deleted successfully
exit 0
