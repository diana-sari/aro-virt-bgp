#!/usr/bin/env bash

# Copy this file outside the repository before adding environment-specific values.
# Do not commit credentials or rendered manifests.

export KUBECONFIG="/path/to/aro.kubeconfig"
export AZURE_SUBSCRIPTION_ID="<subscription-id>"
export AZURE_NETWORK_RESOURCE_GROUP="<network-resource-group>"
export AZURE_ROUTE_SERVER_NAME="<route-server-name>"
export AZURE_TEST_VM_IP="<azure-test-vm-private-ip>"
export MACHINESET_NAME="<worker-machineset-name>"
export CUDN_NAMESPACE="<cudn-namespace>"
export CUDN_NETWORK_NAME="<cudn-network-name>"
export BGP_ROUTING_NAME="<bgp-routing-name>"
export CUDN_VM_NAME="<cudn-vm-name>"
