# ARO Classic BGP Cloud Connector lab

## What this is

This repository is a reproducible lab for the engineering BGP Cloud Connector path on Azure Red Hat OpenShift Classic.

Two ARO Classic authentication paths have been functionally validated: service principal with Cloud Credential Operator passthrough, and managed identities with workload identity.

The lab connects an OpenShift Virtualization VM on a ClusterUserDefinedNetwork to an Azure virtual network through Azure Route Server.

## What this proves

The validated implementation can:

- Discover Azure Route Server addresses and ASN.
- Create and remove Azure Route Server BGP peers.
- Enable IP forwarding on selected ARO worker NICs.
- Generate FRR configuration from `BGPCloudConfiguration`.
- Generate a CUDN and route advertisements from `BGPRouting`.
- Route traffic between a CUDN VM and an Azure VM.
- Reconcile peer state when a BGP router worker is replaced through the OpenShift Machine API.

## What this does not prove

This lab does not validate:

- ARO HCP.
- A final support policy or final product identity design.
- Production scale, performance, or failure-domain design.
- Every upgrade, drift, or disaster-recovery scenario.

The service-principal and MIWI identity models were functionally validated.

This repository makes no support-policy determination about the final product identity design.
In particular, the additive BGP Cloud Connector federated credential on the ARO `machine-api` identity remains an open supportability and product-policy question.

## Validated architecture

```text
CUDN VM 10.100.0.3/16
        |
        | l2bridge on CUDN 10.100.0.0/16
        |
ARO worker FRR routers, local ASN 65001
        |
        | eBGP to 10.0.12.4 and 10.0.12.5
        |
Azure Route Server, ASN 65515
        |
Azure VNet test VM 10.0.10.4
```

The validated lab deployed Azure Route Server in `RouteServerSubnet` at `10.0.12.0/27`.

Current Microsoft guidance requires `RouteServerSubnet` to be `/26` or larger for new deployments.

The operator auto-discovered the Azure Route Server neighbor addresses and ASN, then managed the Azure peer and FRR lifecycle.

No neighbor IPs or Route Server peers were configured manually.

## Validated authentication paths

### ARO Classic with a service principal

- CCO passthrough supplies the cluster service-principal credential to the operator.
- The operator uses the cluster service principal for Azure operations.
- The cluster service principal requires an additional Network Contributor grant on the resource group containing Azure Route Server.

### ARO Classic with MIWI

- A dedicated operator workload identity performs Azure Route Server operations.
- The ARO `machine-api` workload identity performs worker NIC operations.
- `spec.azure.networkInterfaceClientID` selects the `machine-api` identity for NIC calls.
- CCO supplies a federated workload-identity credential with no client secret.

The MIWI path is functionally validated.
The additive operator federated credential on `machine-api` remains an open supportability and product-policy question.
See [ARO Classic MIWI validation](docs/06-aro-classic-miwi-validation.md) for the detailed evidence and caveats.

## Validated versions and artifacts

| Component | Validated value |
|---|---|
| ARO | Classic, service principal and MIWI |
| OpenShift | 4.21.22 |
| OpenShift Virtualization | 4.21.17 |
| BGP Cloud Connector commit | `d317567b54e6d4457246032f952fa6c6b80973c7` |
| Operator image | `quay.io/redhat-user-workloads/bgp-cloud-connector-tenant/bgp-cloud-connector/bgp-cloud-connector-operator@sha256:1acd2ea1727ba868e4cd324730d76b3bdb12d48357b73cdf2b8b67fd80140bc5` |
| Local BGP ASN | 65001 |
| Azure Route Server ASN | 65515 |
| CUDN subnet | `10.100.0.0/16` |

The exact-commit engineering image and manifests were used directly.

The OCP 4.22 file-based catalog and generic 1.0.0 image were not used.

## Results

The CUDN VM at `10.100.0.3` reached the Azure VM at `10.0.10.4` with no packet loss.

The worker lifecycle test also passed:

- The initial router worker used `10.0.2.6`.
- Its Machine was deleted through the OpenShift Machine API.
- The old Node and Route Server peer were removed.
- The MachineSet created a replacement worker.
- The replacement inherited `bgp_router=true` from the MachineSet template.
- The replacement received `10.0.2.7`.
- The operator created the corresponding Azure Route Server peer.
- All six BGP sessions returned to Established.
- Azure continued learning `10.100.0.0/16`.
- The CUDN VM continued reaching `10.0.10.4`.
- The final ping returned 4 of 4 replies with 0 percent loss.

## Repository structure

```text
.
├── README.md
├── docs
│   ├── 00-scope-and-positioning.md
│   ├── 01-prereqs-and-architecture.md
│   ├── 02-aro-classic-sp-runbook.md
│   ├── 03-cudn-virt-validation.md
│   ├── 04-worker-lifecycle-validation.md
│   ├── 05-troubleshooting-and-findings.md
│   └── 06-aro-classic-miwi-validation.md
├── manifests
│   ├── bgp-cloud-configuration.yaml
│   ├── bgp-routing.yaml
│   ├── cudn-vm.yaml
│   └── machineset-router-label-example.yaml
└── scripts
    ├── 00-set-env-example.sh
    ├── validate-bgp-state.sh
    └── validate-cudn-state.sh
```

## Quick start

Start with [the prerequisites and architecture](docs/01-prereqs-and-architecture.md), then follow [the ARO Classic service-principal runbook](docs/02-aro-classic-sp-runbook.md) or review the [ARO Classic MIWI validation](docs/06-aro-classic-miwi-validation.md).

Use the manifests only after replacing their documented placeholders.

## Upstream references

- [OpenShift BGP Cloud Connector](https://github.com/openshift/bgp-cloud-connector)
- [Validated engineering commit](https://github.com/openshift/bgp-cloud-connector/commit/d317567b54e6d4457246032f952fa6c6b80973c7)
- [Azure Route Server overview](https://learn.microsoft.com/azure/route-server/overview)
- [Create an Azure Route Server](https://learn.microsoft.com/azure/route-server/quickstart-create-route-server-portal)
- [openshift/release#85681](https://github.com/openshift/release/pull/85681)
- [openshift/release#86426](https://github.com/openshift/release/pull/86426), related engineering CI provisioning context only. This lab did not use that provisioning flow.
- [openshift/release#86150](https://github.com/openshift/release/pull/86150), MIWI engineering context.
- [bgp-cloud-connector#156](https://github.com/openshift/bgp-cloud-connector/pull/156), MIWI engineering context.
