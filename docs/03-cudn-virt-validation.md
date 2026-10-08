# CUDN and OpenShift Virtualization validation

## 1. Install OpenShift Virtualization

Install a release compatible with the cluster version.

The validated environment used the `stable` channel and CSV `kubevirt-hyperconverged-operator.v4.21.17` on OpenShift 4.21.22.

The test environment initially had all default OperatorHub sources disabled.

Only `redhat-operators` was enabled, and the global pull secret required valid entries for `registry.redhat.io` and `registry.connect.redhat.com` before that catalog recovered.

Those were environment-specific provisioning issues, not BGP Cloud Connector requirements.

## 2. Create routing resources

Set the environment variables from `scripts/00-set-env-example.sh`, then render and apply the namespace and `BGPRouting` example:

```bash
envsubst < manifests/bgp-routing.yaml > /tmp/bgp-routing.yaml
oc apply -f /tmp/bgp-routing.yaml
```

Wait for `BGPRouting/$BGP_ROUTING_NAME` to become Ready.

Verify that the operator creates:

- `ClusterUserDefinedNetwork/cluster-udn-$CUDN_NETWORK_NAME`
- `RouteAdvertisements/bgp-cc-route-advertisements`
- The expected FRR advertisement state

Do not create those generated resources manually.

## 3. Create the test VM

The VM must use the engineering-documented `l2bridge` binding.

Render the SSH public-key placeholder and apply the manifest:

```bash
export SSH_PUBLIC_KEY="$(cat ~/.ssh/id_ed25519.pub)"
envsubst < manifests/cudn-vm.yaml > /tmp/cudn-vm.yaml
oc apply -f /tmp/cudn-vm.yaml
```

Do not commit the rendered file if it contains personal key material.

Wait for the VMI to become Running and Ready.

## 4. Validate routing

From the guest, record:

```bash
ip addr
ip route
ip rule
ip neigh show
ping -c 4 <AZURE_TEST_VM_IP>
```

If ping fails, run `tracepath` when available and stop before changing routing.

The validated guest state was:

- Interface `enp1s0`
- Address `10.100.0.3/16`
- MTU 1400
- Default gateway `10.100.0.1`
- Azure destination `10.0.10.4`
- Four replies from four requests, with 0 percent loss

## 5. Verify Azure route learning

Check each Route Server peer's learned routes:

```bash
az network routeserver peering list-learned-routes \
  --resource-group "$AZURE_NETWORK_RESOURCE_GROUP" \
  --routeserver "$AZURE_ROUTE_SERVER_NAME" \
  --name <peer-name> -o json
```

The validated Route Server learned `10.100.0.0/16` from every selected ARO router worker through both Route Server instances.

The Azure effective-route API did not show an exact `10.100.0.0/16` entry on the test VM NIC even though Route Server learned the route and bidirectional dataplane connectivity succeeded.

Treat control-plane and dataplane evidence together when evaluating this result.
