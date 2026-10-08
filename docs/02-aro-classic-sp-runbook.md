# ARO Classic service-principal runbook

## 1. Create the base ARO cluster

Deploy a fresh ARO Classic cluster with the normal service-principal procedure used by your environment.

Use OpenShift 4.21 or newer.

Do not reproduce the custom CI provisioning flow from `openshift/release#86426` for this product-path lab.

Record the cluster name, Azure resource groups, VNet and subnet names, OpenShift version, and worker MachineSets.

## 2. Create Azure test networking

Create these resources in or connected to the ARO VNet:

1. A subnet named exactly `RouteServerSubnet`, at least `/26` under current Azure guidance.
2. An Azure Route Server and its required public IP.
3. A test subnet and test VM reachable through the VNet.

Do not create Route Server BGP peers manually.

## 3. Grant the cluster principal access

Follow the service-principal procedure in [the prerequisites](01-prereqs-and-architecture.md#3-identity-flow).

The upstream engineering documentation uses Network Contributor on the network resource group containing Route Server.

The validated lab already had broader Contributor access on that resource group, which satisfied the functional requirement but is not presented as the preferred least-privilege assignment.

## 4. Deploy the engineering operator

Use the exact validated commit and image:

```bash
export BGP_CC_COMMIT=d317567b54e6d4457246032f952fa6c6b80973c7
export BGP_CC_IMAGE='quay.io/redhat-user-workloads/bgp-cloud-connector-tenant/bgp-cloud-connector/bgp-cloud-connector-operator@sha256:1acd2ea1727ba868e4cd324730d76b3bdb12d48357b73cdf2b8b67fd80140bc5'

git clone https://github.com/openshift/bgp-cloud-connector.git
git -C bgp-cloud-connector checkout "$BGP_CC_COMMIT"
```

Download only the repository-pinned Kustomize tool, set the manager image in the disposable clone, and render before applying:

```bash
make -C bgp-cloud-connector kustomize

(
  cd bgp-cloud-connector/config/manager
  ../../bin/kustomize edit set image controller="$BGP_CC_IMAGE"
)

bgp-cloud-connector/bin/kustomize build \
  bgp-cloud-connector/config/default > /tmp/bgp-cloud-connector-operator.yaml
```

This modifies only the disposable upstream clone.

Review the rendered namespace, CRDs, RBAC, ServiceAccount, services, webhooks, and Deployment before applying them.

Apply the reviewed render:

```bash
oc apply -f /tmp/bgp-cloud-connector-operator.yaml
```

Do not use the OCP 4.22 file-based catalog on an OCP 4.21 cluster, and do not substitute the generic 1.0.0 image for this exact-commit reproduction.

After deployment, verify the manager and webhook endpoints are healthy.

## 5. Select router workers

For durable inheritance, place the router label in each selected MachineSet's Node metadata template before replacing workers:

```bash
export MACHINESET_NAME="<worker-machineset>"
oc patch machineset "$MACHINESET_NAME" -n openshift-machine-api \
  --type=merge --patch-file manifests/machineset-router-label-example.yaml
```

For existing Nodes, label them explicitly:

```bash
oc label node "<worker-node>" bgp_router=true
```

Confirm that the selected Machines and Nodes are healthy before proceeding.

## 6. Configure BGP Cloud Connector

Set the environment variables in `scripts/00-set-env-example.sh`, then render the CR:

```bash
envsubst < manifests/bgp-cloud-configuration.yaml > /tmp/bgp-cloud-configuration.yaml
oc apply -f /tmp/bgp-cloud-configuration.yaml
```

Wait for `BGPCloudConfiguration/cluster` to reach `Ready`.

Verify:

```bash
oc get bgpcloudconfiguration cluster -o yaml
oc get frrconfiguration -n openshift-frr-k8s
az network routeserver peering list \
  --resource-group "$AZURE_NETWORK_RESOURCE_GROUP" \
  --routeserver "$AZURE_ROUTE_SERVER_NAME" -o table
```

Expected operator-owned behavior includes:

- Route Server endpoint and ASN discovery.
- One Azure peer per selected router worker.
- NIC IP forwarding enabled on selected router workers.
- Generated FRR configuration.
- Two Established BGP sessions per selected worker in this Azure topology.

## 7. Continue to CUDN validation

Proceed to [CUDN and OpenShift Virtualization validation](03-cudn-virt-validation.md) only after the base BGP configuration is healthy.
