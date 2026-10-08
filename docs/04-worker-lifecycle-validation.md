# Worker lifecycle validation

## 1. Purpose

This test verifies that BGP Cloud Connector follows OpenShift Machine API worker replacement and reconciles Azure peer lifecycle automatically.

Worker replacement is disruptive and destructive.

Capture a healthy baseline and obtain explicit approval before deleting a Machine.

## 2. Ensure label inheritance

Identify Node, Machine, and MachineSet ownership:

```bash
export NODE_NAME="<router-node>"
export MACHINE_NAME="<router-machine>"
oc get node "$NODE_NAME" -o jsonpath='{.metadata.annotations.machine\.openshift\.io/machine}{"\n"}'
oc get machine "$MACHINE_NAME" -n openshift-machine-api -o yaml
```

Verify the owning MachineSet contains:

```yaml
spec:
  template:
    spec:
      metadata:
        labels:
          bgp_router: "true"
```

This field populates metadata on the replacement Node.

Do not rely only on a label applied directly to the old Node.

## 3. Capture the baseline

Record:

- MachineSet desired, current, ready, and available replicas.
- Target Machine and Node identity.
- Target Node internal IP.
- Current Azure Route Server peers.
- `BGPCloudConfiguration` conditions.
- FRR BGP session state.
- VM-to-Azure connectivity.

## 4. Replace through the Machine API

Delete only the approved Machine:

```bash
oc delete machine "$MACHINE_NAME" -n openshift-machine-api --wait=false
```

Do not delete the Azure VM directly.

Observe without intervening:

1. Old Machine deletion.
2. Replacement Machine creation by the MachineSet.
3. Old Node removal.
4. Old Azure peer deletion.
5. Replacement Node registration and readiness.
6. Automatic inheritance of `bgp_router=true`.
7. New Azure peer creation.
8. BGP sessions returning to Established.
9. Continued route learning and guest connectivity.

## 5. Validated result

| Event | Observed result |
|---|---|
| Initial worker address | `10.0.2.6` |
| Replacement mechanism | OpenShift Machine API deletion |
| Old peer | Removed automatically |
| Replacement worker address | `10.0.2.7` |
| Router label | Inherited automatically from MachineSet template |
| New peer | Created automatically and reached `Succeeded` |
| FRR sessions | Six sessions Established |
| Advertised network | Azure continued learning `10.100.0.0/16` |
| Dataplane result | `10.100.0.3` reached `10.0.10.4` |
| Final ping | 4 of 4 replies, 0 percent loss |

The replacement Node briefly reported `KubeletNotReady` while joining, then became Ready after normal MachineConfig and node convergence.

No corrective change was required.
