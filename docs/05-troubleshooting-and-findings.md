# Troubleshooting and findings

## 1. Stop-and-report discipline

For an unexpected deployment, reconciliation, permission, schema, or connectivity failure:

1. Stop at the failed step.
2. Capture the exact command, resource, and error.
3. Capture affected Kubernetes and Azure state read-only.
4. Capture relevant conditions and focused log excerpts.
5. State the likely cause and proposed next steps.
6. Obtain approval before changing the environment.

## 2. Route Server subnet name

Azure Route Server requires a subnet named exactly `RouteServerSubnet`.

The initial lab attempt used `AzureRouteServerSubnet`, which caused an incomplete deployment.

The incorrect empty subnet and incomplete Route Server were removed after approval, then recreated with the required name.

## 3. FRR webhook startup race

Initial reconciliation reported `FRRConfigurationApplied=False` because `frr-k8s-webhook-service` temporarily had no healthy endpoint.

Normal reconciliation retried and recovered without configuration changes.

Verify webhook endpoints and wait for startup convergence before treating this transient state as a persistent operator failure.

## 4. Missing Azure integration test plan

At the validated commit, `docs/azure-integration-test-plan.md` did not exist while an AWS integration test plan did.

This was treated as an engineering documentation gap, not a deployment blocker.

## 5. OperatorHub and registry credentials

All default OperatorHub sources were disabled in the test cluster.

Only `redhat-operators` was enabled for OpenShift Virtualization.

The global pull secret initially lacked valid entries for `registry.redhat.io` and `registry.connect.redhat.com`.

After a targeted credential merge that preserved the existing ARO registry entry, the catalog recovered automatically.

These were provisioning-default issues in the lab environment, not expected BGP Cloud Connector workflow steps.

Never print or commit pull-secret contents.

## 6. `disableMP` warning

The generated FRR configuration emitted a deprecation warning for `disableMP`.

The generated configuration remained functional and all sessions became Established.

Track the upstream API migration rather than editing operator-generated FRR resources.

## 7. KubeVirt streaming issue

An initial `virtctl` client and server version mismatch produced WebSocket close code 1006.

Using cluster-matching `virtctl` v1.7.4 enabled the initial guest dataplane validation in the MIWI lab.

The streaming failure later recurred with the matching client during post-replacement access.
Logs also reported missing `virt-handler` client certificate files under `/etc/virt-handler/clientcertificates/`.
The VM remained Running and Ready, and the serial console connected, but the key-only guest had no console password.

This is an OpenShift Virtualization or KubeVirt streaming finding, not a BGP Cloud Connector failure.
Using a matching client is an important first diagnostic step, but it is not a guaranteed fix for every WebSocket close 1006 failure.

## 8. Azure effective-route discrepancy

The Azure test VM NIC effective-route API did not display an exact `10.100.0.0/16` entry.

At the same time:

- Azure Route Server learned `10.100.0.0/16` from the ARO peers.
- FRR sessions were Established.
- The CUDN VM reached the Azure VM successfully.

Record the discrepancy, but do not infer dataplane failure from that API result alone.

## 9. Useful read-only checks

```bash
oc get bgpcloudconfiguration cluster -o yaml
oc get bgprouting -o yaml
oc get frrconfiguration -n openshift-frr-k8s -o yaml
oc get clusteruserdefinednetwork
oc get routeadvertisements
oc get nodes -l bgp_router=true -o wide

az network routeserver peering list \
  --resource-group "$AZURE_NETWORK_RESOURCE_GROUP" \
  --routeserver "$AZURE_ROUTE_SERVER_NAME" -o table
```
