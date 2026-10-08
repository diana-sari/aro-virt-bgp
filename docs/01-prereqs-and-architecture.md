# Prerequisites and architecture

## 1. Required access and tools

- An Azure subscription where ARO and Azure Route Server can be created.
- Permission to create ARO Classic with a service principal.
- Permission to assign Network Contributor on the network resource group.
- Azure CLI authenticated to the target subscription.
- `oc`, `kubectl`, `jq`, `git`, and `virtctl` matching the OpenShift Virtualization version.
- A workstation that can reach the public or private ARO API endpoint.

Never store kubeconfigs, service-principal secrets, pull secrets, or Terraform state in this repository.

## 2. Validated topology

The validated cluster had three `Standard_D4s_v3` workers across three zones.

All three were selected as BGP routers with `bgp_router=true`.

Azure resources used:

| Resource | Validated setting |
|---|---|
| ARO VNet | Existing cluster VNet |
| Route Server subnet | `RouteServerSubnet`, `10.0.12.0/27` |
| Route Server | ASN 65515, virtual router IPs `10.0.12.4` and `10.0.12.5` |
| Test subnet | Address space containing `10.0.10.4` |
| Azure test VM | Private address `10.0.10.4` |
| CUDN | `10.100.0.0/16` |
| CUDN test VM | `10.100.0.3` during validation |

The exact host addresses and `/27` Route Server subnet are historical observations, not required static assignments for another deployment.

Current Microsoft guidance requires `RouteServerSubnet` to be `/26` or larger for new deployments.

## 3. Identity flow

ARO Classic service-principal clusters use CCO passthrough for this path.

The operator creates a `CredentialsRequest`, and CCO supplies the cluster service-principal credential.

Determine the client ID without printing any client secret:

```bash
client_id=$(oc -n kube-system get secret azure-credentials \
  -o jsonpath='{.data.azure_client_id}' | base64 -d)
object_id=$(az ad sp show --id "$client_id" --query id -o tsv)
```

Grant that object Network Contributor on the resource group containing Azure Route Server:

```bash
az role assignment create \
  --assignee-object-id "$object_id" \
  --assignee-principal-type ServicePrincipal \
  --role "Network Contributor" \
  --scope "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_NETWORK_RESOURCE_GROUP}"
```

Allow time for Azure RBAC propagation before diagnosing an authorization failure.

## 4. Azure Route Server requirements

The subnet name must be exactly `RouteServerSubnet` and must be `/26` or larger under current Azure guidance.

The completed historical lab successfully used `10.0.12.0/27`.

Do not manually configure BGP peers.

Create Route Server and the Azure test VM, then let BGP Cloud Connector discover Route Server and manage peers.

## 5. OpenShift requirements

- OpenShift 4.21 or newer.
- FRR and route-advertisement APIs available after operator reconciliation.
- Dedicated or intentionally selected worker nodes for BGP routing.
- OpenShift Virtualization for the VM validation phase.
- A `l2bridge` binding for the VM interface on the CUDN.
