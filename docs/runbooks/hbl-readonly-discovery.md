# hbl Read-Only Discovery Runbook

Status: draft.
Purpose: discover the current deployment mechanism without changing production state.

## Safety

- Do not print secret values.
- Do not run `kubectl edit`, `kubectl patch`, `kubectl apply`, `helm upgrade`, `helm rollback`, `systemctl restart`, or file writes during discovery.
- Record secret names only.
- Stop if a command would reveal a secret value.

## Read-Only Checks

Use SSH to hbl with the approved admin key.

```powershell
ssh -i C:\Users\User\.ssh\nof-admin-hbl nofadminhbl@192.168.1.51 "hostname && whoami"
```

Inspect likely deploy mechanisms:

```bash
systemctl list-units --type=service --all | grep -Ei 'nof|hbl|runner|deploy|webhook|github|release'
systemctl list-timers --all | grep -Ei 'nof|hbl|runner|deploy|webhook|github|release'
ps aux | grep -Ei 'nof|hbl|runner|deploy|webhook|github|release' | grep -v grep
```

Inspect Kubernetes/Helm state without secrets:

```bash
sudo microk8s kubectl get ns
sudo microk8s kubectl get deploy,svc,ingress,configmap,secret -n nof-apps
sudo microk8s helm3 list -A
```

Inspect image names:

```bash
sudo microk8s kubectl get deploy -n nof-apps -o jsonpath='{range .items[*]}{.metadata.name}{" "}{range .spec.template.spec.containers[*]}{.image}{" "}{end}{"\n"}{end}'
```

Inspect config keys without values:

```bash
sudo microk8s kubectl get configmap -n nof-apps -o name
sudo microk8s kubectl get secret -n nof-apps -o name
```

## Evidence To Record

- Which service or script deploys after GitHub merge/tag/release.
- Helm release names.
- Docker image names.
- Kubernetes deployment names.
- Public hostnames.
- Secret names and owning service, without values.
- Legacy identifiers that must be migrated.
