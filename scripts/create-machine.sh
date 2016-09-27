#! /bin/bash

docker-machine create \
    -d azure \
    --azure-location=westeurope \
    --azure-resource-group=voxxed \
    --azure-size=Standard_A1 \
    --azure-subscription-id=$AZURE_SUBSCRIPTION_ID \
    "$@"
