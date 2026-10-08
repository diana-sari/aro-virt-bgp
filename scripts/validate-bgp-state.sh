#!/usr/bin/env bash

set -euo pipefail

: "${KUBECONFIG:?Set KUBECONFIG to the target cluster kubeconfig}"
: "${AZURE_NETWORK_RESOURCE_GROUP:?Set AZURE_NETWORK_RESOURCE_GROUP}"
: "${AZURE_ROUTE_SERVER_NAME:?Set AZURE_ROUTE_SERVER_NAME}"

oc get bgpcloudconfiguration cluster -o jsonpath='{.status.phase}{"\n"}'
oc get bgpcloudconfiguration cluster \
  -o jsonpath='{range .status.conditions[*]}{.type}{"="}{.status}{" reason="}{.reason}{"\n"}{end}'

oc get nodes -l bgp_router=true \
  -o custom-columns='NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,IP:.status.addresses[?(@.type=="InternalIP")].address'

oc get frrconfiguration -n openshift-frr-k8s -o wide
oc get pods -n openshift-frr-k8s -l app=frr-k8s -o wide

az network routeserver peering list \
  --resource-group "$AZURE_NETWORK_RESOURCE_GROUP" \
  --routeserver "$AZURE_ROUTE_SERVER_NAME" \
  --query '[].{name:name,peerIp:peerIp,peerAsn:peerAsn,provisioningState:provisioningState}' \
  -o table
