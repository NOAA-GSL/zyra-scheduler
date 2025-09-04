# zyra-workflows Helm Chart

Deploy Zyra dataset workflows as Kubernetes CronJobs. Each dataset becomes a CronJob that runs the example Zyra pipeline (acquire → validate → compose → optional upload/update).

Important
- This chart and its defaults are examples meant as a starting point. Clone and adapt for your workflows and datasets.
- The sample datasets and schedules shown in values.yaml and docs are illustrative; set your own.

Install
1) Create (or reuse) a namespace
   - `kubectl create namespace zyra`
2) Configure values.yaml (dataset list, schedules, image, PVC) — samples provided
   - See `values.yaml` for examples. You can reference an existing ConfigMap per dataset (`envFromConfigMap`) or inline the dataset env under `env:` to generate a ConfigMap.
3) Ensure a PVC exists (chart can create one)
   - Set `global.pvc.create=true` and adjust size/class, or create your own and set `global.pvc.create=false` with `global.pvc.name` set.
4) Provide secrets as needed
   - Create `vimeo-secrets` and `aws-secrets` in the target namespace (or change names in values).
5) Install
   - `helm upgrade --install zyra ./charts/zyra-workflows -n zyra`

Values (high‑level, sample‑oriented)
- `global.image`: container image for jobs (pin a digest in production).
- `global.imagePullSecrets`: list of imagePullSecrets names.
- `global.verbosity`: Zyra log level (debug|info|quiet).
- `global.resources`: resource requests/limits for the job container.
- `global.pvc`: PVC settings (`create`, `name`, `size`, `storageClassName`).
- `datasets`: array of dataset entries:
  - `name`: dataset env stem.
  - `enabled`: whether to render the CronJob.
  - `schedule`: 5‑field cron (UTC).
  - `envFromConfigMap`: existing ConfigMap name to load dataset variables from (optional).
  - `env`: map of dataset variables (optional, generates a ConfigMap when set).
  - `vimeoSecretName`, `awsSecretName`: secret names if using those stages.

Notes
- The pipeline writes frames to `/data/images/<dataset>`, outputs to `/data/output/<dataset>.mp4` via a PVC.
- If neither `envFromConfigMap` nor `env` is set for a dataset, the job will lack required variables and fail early.
- For Rancher UI, import this chart and configure dataset entries via the form or YAML.
