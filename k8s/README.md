# Deploying Zyra Workflows on Kubernetes (Rancher)

This folder contains example manifests and guidance to run the example Zyra pipeline on a Kubernetes cluster (including Rancher‑managed clusters). These are samples — clone and adapt for your own workflows and datasets.

Concepts
- Use a CronJob per dataset to mirror the per‑dataset schedules from CI (or run Jobs manually).
- Persist frame caches and outputs across runs with a PersistentVolumeClaim mounted at `/data`.
- Load non‑secret dataset configuration via a ConfigMap generated from `datasets/<name>.env`.
- Provide Vimeo/AWS credentials via Kubernetes Secrets (env vars).
- Use the `ghcr.io/noaa-gsl/zyra-scheduler` image (pin by digest for production).

Prereqs
- Namespace created (e.g., `zyra`).
- Image pull access for GHCR if required (add an `imagePullSecrets` on the workload or ServiceAccount).
- Network egress to FTP, Vimeo, and S3 endpoints.

Quick start (drought example)
1) Create namespace (optional)
   - `kubectl create namespace zyra`
2) Create dataset ConfigMap from the existing env file
   - `kubectl -n zyra create configmap dataset-drought --from-env-file=../datasets/drought.env`
3) Create Vimeo and AWS Secrets (example; replace values)
   - `kubectl -n zyra create secret generic vimeo-secrets \
       --from-literal=VIMEO_CLIENT_ID=xxx \
       --from-literal=VIMEO_CLIENT_SECRET=xxx \
       --from-literal=VIMEO_ACCESS_TOKEN=xxx`
   - `kubectl -n zyra create secret generic aws-secrets \
       --from-literal=AWS_ACCESS_KEY_ID=xxx \
       --from-literal=AWS_SECRET_ACCESS_KEY=xxx`
4) Create a PVC for persistent caches/outputs
   - Review `pvc.yaml` and apply: `kubectl -n zyra apply -f pvc.yaml`
5) Apply the dataset CronJob
   - Review `cronjob-drought.yaml` and update the `schedule:` if desired.
   - `kubectl -n zyra apply -f cronjob-drought.yaml`

Notes
- Logs: `kubectl -n zyra logs job/<job-name>` after a scheduled run.
- Manual run: create a one‑off Job by copying the Job spec from the CronJob’s `jobTemplate`.
- Storage: adjust `resources.requests.storage` and `storageClassName` in `pvc.yaml` for your cluster.
- Scheduling: set `concurrencyPolicy: Forbid` to avoid overlapping runs; tune `backoffLimit` as needed.
- Security: you may set `securityContext` (e.g., `runAsNonRoot`) if your base image supports it. The example runs as root.

Helm alternative
- A Helm chart is included under `charts/zyra-workflows` to manage multiple datasets as CronJobs.
- Add datasets in `values.yaml` (either reference an existing ConfigMap or inline env to auto‑generate one).
- Install with: `helm upgrade --install zyra ./charts/zyra-workflows -n zyra`.
