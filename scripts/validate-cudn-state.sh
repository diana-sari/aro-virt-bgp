#!/usr/bin/env bash

set -euo pipefail

: "${KUBECONFIG:?Set KUBECONFIG to the target cluster kubeconfig}"
: "${AZURE_TEST_VM_IP:?Set AZURE_TEST_VM_IP}"
: "${CUDN_NAMESPACE:?Set CUDN_NAMESPACE}"
: "${CUDN_NETWORK_NAME:?Set CUDN_NETWORK_NAME}"
: "${BGP_ROUTING_NAME:?Set BGP_ROUTING_NAME}"
: "${CUDN_VM_NAME:?Set CUDN_VM_NAME}"

oc get bgprouting "$BGP_ROUTING_NAME" -o yaml
oc get clusteruserdefinednetwork "cluster-udn-$CUDN_NETWORK_NAME" -o yaml
oc get routeadvertisements bgp-cc-route-advertisements -o yaml
oc get virtualmachine "$CUDN_VM_NAME" -n "$CUDN_NAMESPACE" -o wide
oc get virtualmachineinstance "$CUDN_VM_NAME" -n "$CUDN_NAMESPACE" -o wide

printf '%s\n' 'Guest connectivity must be checked from the VM console:'
printf '%s\n' '  ip route'
printf '%s\n' '  ip rule'
printf '%s\n' '  ip neigh show'
printf '  ping -c 4 %q\n' "$AZURE_TEST_VM_IP"
