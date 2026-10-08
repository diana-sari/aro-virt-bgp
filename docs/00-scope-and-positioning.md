# Scope and positioning

## 1. Validated path

This lab validates one specific path:

```text
ARO Classic + service principal + CCO passthrough + Azure Route Server
```

The operator creates a `CredentialsRequest`, and CCO writes `bgp-cloud-connector-azure-credentials` in the operator namespace.

In passthrough mode, that secret contains the cluster principal credential, which the operator uses to manage Route Server peers and worker NIC IP forwarding.

The administrator reads `kube-system/azure-credentials` to identify the cluster principal for the Azure role grant.

The operator does not read `kube-system/azure-credentials` directly.

## 2. Product positioning

The test demonstrates that the service-principal identity path works functionally with the tested engineering implementation.

It does not determine whether that identity model will be the final supported product design.

It does not validate MIWI, ARO Classic with managed identities, or ARO HCP.

References to managed identity work are included only to distinguish future work from the path validated here.

## 3. Engineering source of truth

The lab follows the implementation and documentation at commit `d317567b54e6d4457246032f952fa6c6b80973c7`, especially:

- `docs/deployment.md`
- `docs/azure-authentication.md`
- `docs/cloud-integration.md`
- `docs/reconciliation.md`
- `docs/kubevirt-testing.md`
- `docs/custom-resources.md`
- CRDs and samples under `config/`

The missing `docs/azure-integration-test-plan.md` is recorded as a documentation gap.

## 4. Deliberate exclusions

This lab does not use the older manual MOBB PoC mechanisms.

Do not manually create Route Server peers, hardcode Route Server neighbor addresses, create `FRRConfiguration`, create operator-owned `RouteAdvertisements`, or deploy peer-manager and NIC-forwarding DaemonSets.

The operator is expected to own those actions.

The custom CI provisioning logic associated with `openshift/release#86426` is not part of this runbook.
