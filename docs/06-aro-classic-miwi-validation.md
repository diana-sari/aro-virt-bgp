# ARO Classic MIWI BGP Cloud Connector PoC Findings

## 1. Scope

This proof of concept validated the current BGP Cloud Connector managed identity and workload identity implementation on ARO Classic.

- Platform: ARO Classic
- OpenShift version: `4.21.22`
- Identity model: Azure user-assigned managed identities and workload identity
- BGP Cloud Connector source commit: `d317567b54e6d4457246032f952fa6c6b80973c7`
- Operator image: `quay.io/redhat-user-workloads/bgp-cloud-connector-tenant/bgp-cloud-connector/bgp-cloud-connector-operator@sha256:1acd2ea1727ba868e4cd324730d76b3bdb12d48357b73cdf2b8b67fd80140bc5`

This PoC validates functional behavior only.
It does not resolve the open ARO support-policy question about adding a federated credential for the BGP Cloud Connector ServiceAccount to the ARO `machine-api` identity.

## 2. ARO MIWI provisioning

The cluster was provisioned as follows:

- Cluster: `bgp-test-miwi-v0`
- OpenShift version: `4.21.22`
- Identity type: `UserAssigned`
- ARO user-assigned managed identities: nine
- Azure CLI: official side-by-side macOS ARM64 release `2.90.0`
- Base identities and RBAC: `az aro identity create-required`
- Additional RBAC: four BYO NSG-scoped role assignments

All nine expected identities were created in `bgp-test-v0-rg`:

- `aro-cluster`
- `aro-operator`
- `cloud-controller-manager`
- `cloud-network-config`
- `disk-csi-driver`
- `file-csi-driver`
- `image-registry`
- `ingress`
- `machine-api`

All platform workload identities were associated with the cluster successfully.
The cluster reached `Succeeded`, all six nodes became Ready, and all 33 ClusterOperators reported `Available=True` and `Degraded=False`.

## 3. BGP Cloud Connector identity model

The implementation used a split identity model.

The dedicated operator identity was:

```text
bgp-test-miwi-v0-bgp-cloud-connector
```

It received `Network Contributor` scoped only to `bgp-test-v0-rg`.

The operator ServiceAccount subject was:

```text
system:serviceaccount:openshift-bgp-cloud-connector:openshift-bgp-cloud-connector-controller-manager
```

Federated identity credentials with audience `openshift` were created on:

- The dedicated BGP Cloud Connector identity
- The existing ARO `machine-api` identity

The ARO-managed `machine-api` federated credential was preserved unchanged for:

```text
system:serviceaccount:openshift-machine-api:machine-api-controllers
```

The `BGPCloudConfiguration` used the ARO `machine-api` managed identity client ID:

```text
networkInterfaceClientID = <machine-api-client-id>
```

The live client ID is intentionally omitted from this public document.

## 4. CCO and workload identity result

`CredentialsRequest/bgp-cloud-connector-azure` was created when `BGPCloudConfiguration/cluster` began reconciliation.
The Cloud Credential Operator generated `openshift-bgp-cloud-connector/bgp-cloud-connector-azure-credentials` successfully.

The generated credential contained:

- `azure_federated_token_file`
- The dedicated BGP Cloud Connector identity client ID
- Azure tenant, subscription, and region metadata

The generated credential did not contain `azure_client_secret`.
The dedicated BGP Cloud Connector identity was the primary operator credential.
The `machine-api` identity was not used as the primary operator credential.

## 5. Azure identity attribution

Azure Activity Logs confirmed the intended split identity behavior.

Worker NIC operations were:

- Performed by the ARO `machine-api` identity
- Not performed by the dedicated BGP Cloud Connector identity

Azure Route Server peer operations were:

- Performed by the dedicated BGP Cloud Connector identity
- Not performed by the ARO `machine-api` identity

The worker replacement test produced the same attribution.
The replacement NIC writes were attributed to `machine-api`, while the replacement Route Server peer write was attributed to the dedicated operator identity.

This evidence confirms that the current implementation separates Route Server operations from worker NIC operations as designed.

## 6. BGPCloudConfiguration result

`BGPCloudConfiguration/cluster` reached `Ready` with:

- Router selector: `bgp_router=true`
- Local ASN: `65001`
- Azure Route Server ASN: `65515`
- Route Server endpoint: `10.0.12.4`
- Route Server endpoint: `10.0.12.5`
- Selected router workers: three
- Worker NICs with IP forwarding: exactly three
- Azure Route Server peers: exactly three
- BGP sessions: six, all `Established`

The healthy conditions were:

- `NetworkOperatorPatched=True`
- `FRRNamespaceReady=True`
- `CloudEndpointsDiscovered=True`
- `FRRConfigurationApplied=True`
- `CompleteNodeInventory=True`
- `CloudResourcesReconciled=True`

## 7. Dataplane validation

The routed workload topology used:

- `BGPRouting` subnet: `10.100.0.0/16`
- CUDN: `cluster-udn-bgp-test-miwi-v0`
- VM: `bgp-test-miwi-v0-cudn-vm`
- VM network binding: `l2bridge`
- VM address: `10.100.0.3/16`
- Default gateway: `10.100.0.1`
- Interface MTU: 1400

Azure Route Server learned `10.100.0.0/16` from all three router workers across both Route Server instances.
Each learned path reported origin `EBgp` and AS path `65001`.

The guest successfully reached the preserved Azure test VM at `10.0.10.4`:

```text
4 packets transmitted, 4 received, 0% packet loss
rtt min/avg/max/mdev = 7.437/11.863/15.592/3.313 ms
```

## 8. Worker lifecycle validation

One router worker was replaced through the OpenShift Machine API.

The old worker was:

- Node and Machine: `bgp-test-miwi-v0-wphxs-worker-westus21-bp5nn`
- Internal IP: `10.0.2.5`
- MachineSet: `bgp-test-miwi-v0-wphxs-worker-westus21`

The replacement was:

- Node and Machine: `bgp-test-miwi-v0-wphxs-worker-westus21-b2w98`
- Internal IP: `10.0.2.7`
- MachineSet: `bgp-test-miwi-v0-wphxs-worker-westus21`

The following lifecycle behavior was observed:

- The replacement inherited `bgp_router=true` from the MachineSet template.
- The replacement Node became Ready.
- The MachineSet returned to desired, current, ready, and available replicas of `1/1/1/1`.
- The old Route Server peer for `10.0.2.5` was removed automatically.
- A new Route Server peer for `10.0.2.7` was created automatically.
- NIC IP forwarding was enabled automatically on the replacement worker.
- Two replacement BGP sessions reached `Established`.
- The total BGP session count returned to six of six `Established`.
- `BGPCloudConfiguration/cluster` returned to `Ready`.
- Azure learned `10.100.0.0/16` through replacement next hop `10.0.2.7` on both Route Server instances.
- The learned AS path remained `65001`.
- No manual Azure route, Route Server peer, NIC, identity, FIC, or RBAC repair was required.

Azure Activity Logs attributed the replacement NIC writes to `machine-api` and the replacement peer write to the dedicated BGP Cloud Connector identity.

## 9. OpenShift Virtualization observation

An intermittent `virtctl` WebSocket close 1006 was observed and is tracked separately from the BGP validation.

- Matching `virtctl` v1.7.4 successfully enabled the initial guest dataplane test.
- The WebSocket failure recurred during post-replacement guest access.
- The VM remained Running and Ready with address `10.100.0.3`.
- The serial console connected successfully but presented a login prompt.
- The guest was configured for SSH-key-only access and had no console password.
- No post-replacement ping was run.

No evidence indicated a BGP Cloud Connector or CUDN dataplane failure.
The VM remained on an unaffected worker throughout the router worker replacement.

## 10. Overall conclusion

Functional validation of ARO Classic with MIWI and BGP Cloud Connector succeeded.

- The dedicated operator identity successfully handled Azure Route Server operations.
- The ARO `machine-api` identity successfully handled worker NIC forwarding operations.
- CCO workload identity integration worked without client secrets.
- Routed CUDN connectivity from the OpenShift Virtualization VM to the Azure test VM succeeded.
- Router worker replacement reconciled automatically without manual cloud intervention.

Borrowing `machine-api` through an additive federated credential remains a supportability and product-policy question.
This PoC does not resolve or make a support-policy determination about that design.

## 11. Comparison with the service-principal PoC

The service-principal path used:

- CCO passthrough
- The cluster service principal for Azure operations
- An additional Network Contributor grant on the Route Server resource group

The MIWI path used:

- A dedicated operator workload identity for Route Server operations
- The ARO `machine-api` workload identity for worker NIC operations
- `spec.azure.networkInterfaceClientID` to select the NIC identity
- A CCO-generated federated credential with no client secret

## 12. Teardown status

Teardown has not started.
All MIWI PoC resources remain in place pending review and explicit teardown approval.
