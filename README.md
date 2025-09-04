# Zyra Workflow Template

## Overview
This repository is a starter template for building containerized workflows with the [Zyra](https://github.com/NOAA-GSL/zyra) CLI. It provides a ready‑to‑use dev container, a reusable GitHub Actions workflow, and example datasets to demonstrate a full pipeline. Clone and adapt it to your own sources, transforms, and outputs.

Included example: a real‑time image‑to‑video pipeline (FTP → metadata validate → MP4 compose → optional Vimeo upload → optional S3 update). Treat this as a reference implementation you can modify or replace with your own stages.

## Quick Start: Add a Dataset
- Create `datasets/<name>.env` with the required keys (see `datasets/README.md`).
- Run the GitHub Actions workflow manually with input `DATASET_NAME=<name>` to validate:
  - Acquire → frames under `_work/images/${DATASET_NAME}`.
  - Validate → metadata under `_work/images/${DATASET_NAME}/metadata/frames-meta.json`.
  - Compose → video at `_work/output/${DATASET_NAME}.mp4`.
- Configure credentials for upload/update stages via GitHub Secrets (Vimeo and AWS). For local development, place non-secret values in your project `.env` and keep it untracked.
- Schedule it: enable a cron in the per‑dataset wrapper under `.github/workflows/` (uncomment the `schedule:` block), or create your own wrapper with the desired cron.

### Scheduling Tips
- Cron examples: `30 3 * * *` (daily 03:30), `5 12 * * 4` (Thu 12:05). Times are UTC in GitHub Actions.
- Variables: set `DATASET_NAME` in the wrapper’s `with:` section; use repo variables to share defaults (e.g., `ZYRA_SCHEDULER_IMAGE`).
- Concurrency: multiple wrappers can run concurrently; frames are cached per dataset.
- Reliability: pin the container image by digest; start with a smaller `SINCE_PERIOD` (e.g., `P30D`) to seed caches faster.

## Current Datasets
These are example datasets provided for demonstration. Each has a per‑dataset workflow under `.github/workflows/` with its cron schedule commented out. You can still run any of them manually from GitHub → Actions by choosing the corresponding dataset workflow, or re‑enable its schedule by uncommenting the `schedule:` block.

The following examples are configured in `datasets/*.env`. Suggested crons are shown for reference if you choose to re‑enable scheduling.

How to run manually
- GitHub → Actions → choose the per‑dataset workflow (e.g., “Dataset (drought)”).
- Click “Run workflow” and confirm the branch (typically `main`).
- The run will use the dataset’s `.env` and produce artifacts under `_work/`.

| Dataset (env) | Suggested Cron | When | Cadence | FTP (host + path) | Pattern | Basemap | Vimeo |
|---|---|---|---|---|---|---|---|
| drought (`drought.env`) | `5 12 * * 4` | Thu 12:05 | 7d | `ftp.nnvl.noaa.gov` `/SOS/DroughtRisk_Weekly` | `DroughtRisk_Weekly_YYYYMMDD.png` | — | `/videos/900195230` |
| fire (`fire.env`) | `30 0 * * *` | Daily 00:30 | 1d | `public.sos.noaa.gov` `/rt/fire/4096` | `fire_YYYYMMDD.png` | `earth_vegetation.jpg` | `/videos/919356484` |
| ozone (`ozone.env`) | `45 1 * * *` | Daily 01:45 | 1d | `public.sos.noaa.gov` `/rt/ozone/4096` | `ozone_YYYYMMDD.png` | — | `/videos/919343002` |
| land_temp (`land_temp.env`) | `25 2 * * *` | Daily 02:25 | 1d | `public.sos.noaa.gov` `/rt/land_temp/4096` | `land_temp_YYYYMMDD.png` | — | `/videos/920212337` |
| sst (`sst.env`) | `30 3 * * *` | Daily 03:30 | 1d | `public.sos.noaa.gov` `/rt/sst/nesdis/sst/4096` | `sst_YYYYMMDD.png` | — | `/videos/920241809` |
| sst-anom (`sst-anom.env`) | `45 4 * * *` | Daily 04:45 | 1d | `public.sos.noaa.gov` `/rt/sst/nesdis/sst_anom/4096` | `sst_anom_YYYYMMDD.png` | `earth_vegetation.jpg` | `/videos/920245845` |
| snow_ice (`snow_ice.env`) | `25 5 * * *` | Daily 05:25 | 1d | `public.sos.noaa.gov` `/rt/snow_ice/4096` | `snow_ice_YYYYMMDD.png` | — | `/videos/920619332` |
| clouds (`clouds.env`) | `10 6 * * *` | Daily 06:10 | 10m | `ftp.sos.noaa.gov` `/sosrt/rt/noaa/sat/linear/raw` | `linear_rgb_cyl_YYYYMMDD_HHMM.jpg` | — | `/videos/907632335` |
| enhanced-clouds (`enhanced-clouds.env`) | `30 7 * * *` | Daily 07:30 | 10m | `ftp.sos.noaa.gov` `/sosrt/rt/noaa/sat/enhanced/raw` | `enhanced_rgb_cyl_YYYYMMDD_HHMM.jpg` | — | `/videos/920672356` |
| precip (`precip.env`) | `45 8 * * *` | Daily 08:45 | 30m | `public.sos.noaa.gov` `/rt/precip/3600` | `imergert_composite.YYYY-MM-DDTHH_MM_SSZ.png` | — | `/videos/921800789` |
| precip-water (`precip-water.env`) | `45 9 * * *` | Daily 09:45 | 1d | `public.sos.noaa.gov` `/rt/precipitable_water/4096` | `pw_YYYYMMDD.png` | — | `/videos/923507546` |

Notes
- Basemap: when `BASEMAP_IMAGE` is set in the dataset env, the compose stage includes it via `--basemap <file>`.
- Cadence: derived from `PERIOD_SECONDS` in each env; adjust to match source update intervals.

## Usage & Scheduling
- Primary CI: GitHub Actions (reusable workflow and per‑dataset wrappers).
- Contributor guide: see `AGENTS.md` for structure, style, testing, and PR guidelines.
- Local development: `docker compose up --build -d` and `docker compose exec zyra-scheduler bash`. The devcontainer layers Node.js + Codex CLI on top of a runtime image. If no runtime is provided, it falls back to `python:3.11-slim` for lint/tests.

### GitHub Actions
- Reusable workflow: `.github/workflows/zyra.yml` implements the example pipeline stages (acquire → validate → compose → upload → update). Modify the steps or add your own Zyra commands to fit your needs.
- Manual run: Actions → Zyra Video Pipeline → Run workflow with input `DATASET_NAME` (e.g., `drought`). Optional inputs: `ZYRA_VERBOSITY` and `ZYRA_SCHEDULER_IMAGE`.
- Scheduling: use per‑dataset wrappers (below). The reusable workflow itself has no cron.
- Runtime container: defaults to `ghcr.io/noaa-gsl/zyra-scheduler:latest`. Override with workflow input or repo variable `ZYRA_SCHEDULER_IMAGE` (prefer pinned digest).
- Working paths: binds the repo to `/app` and a workspace data dir to `/data` inside the job container.
- Cache: caches `_work/images/$DATASET_NAME` keyed by dataset name to speed up runs.
- Secrets (optional stages):
  - Vimeo upload: `VIMEO_CLIENT_ID`, `VIMEO_CLIENT_SECRET`, `VIMEO_ACCESS_TOKEN`.
  - S3 update: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` (and `S3_URL` in the dataset env).

Per‑dataset schedules (template style)
- The main workflow is also reusable via `workflow_call`. Create tiny wrappers per dataset with their own cron and fixed dataset name.
- Example (`.github/workflows/dataset-drought.yml`):
  - `on.schedule: '45 4 * * *'` (daily 04:45 UTC)
  - `jobs.run.uses: ./.github/workflows/zyra.yml`
  - `jobs.run.with.DATASET_NAME: drought`
  - `jobs.run.secrets: inherit` to pass Vimeo/AWS secrets.
- Repeat for each dataset (`dataset-<name>.yml`), setting the appropriate cron and dataset env stem (must match `datasets/<name>.env`). The top‑level `zyra.yml` intentionally has no cron.

###

## Setup
- Create a `.env` from `.env.example` and set:
  - `HOST_DATA_PATH`: absolute host path for `/data` bind mount.
  - (Optional) `ZYRA_SCHEDULER_IMAGE`: container image to use for CI/devcontainer. If omitted, the devcontainer uses `python:3.11-slim`, which is sufficient for local linting and tests.

### Image source
The recommended runtime image is published on GitHub Container Registry:
`ghcr.io/noaa-gsl/zyra-scheduler:latest`.

If your environment cannot access GHCR, set `ZYRA_SCHEDULER_IMAGE` to an accessible tag in your own registry and `docker login` to that registry. For local development only, you may omit `ZYRA_SCHEDULER_IMAGE` to fall back to `python:3.11-slim`.

### Example
```
cp .env.example .env
# Option A: Use GHCR latest (recommended)
export ZYRA_SCHEDULER_IMAGE=ghcr.io/noaa-gsl/zyra-scheduler:latest
docker login ghcr.io

# Option B: Comment/remove ZYRA_SCHEDULER_IMAGE in .env to use python:3.11-slim

docker compose up --build -d
docker compose exec zyra-scheduler bash
```

Security note: never commit real secrets. Keep `.env` untracked (see `.gitignore`) and set credentials via environment or your secrets store.

## Local Debugging (Dev Container)
- Enter the container:
  - `docker compose exec zyra-scheduler bash`
- Load a dataset env (example: fire):
  - `export DATASET_NAME=fire`
  - `set -a; . datasets/$DATASET_NAME.env; set +a`
  - Verify: `echo "$FTP_HOST $FTP_PATH"` and `env | grep -E '^(DATASET_ID|FTP_|VIMEO_URI|SINCE_PERIOD|PERIOD_SECONDS|PATTERN|DATE_FORMAT|BASEMAP_IMAGE)='`
- Prepare working dirs (mirrors CI paths):
  - `export DATA_ROOT="$PWD/_work"`
  - `export FRAMES_DIR="$DATA_ROOT/images/$DATASET_NAME"`
  - `export OUTPUT_DIR="$DATA_ROOT/output"`
  - `export OUTPUT_PATH="$OUTPUT_DIR/$DATASET_NAME.mp4"`
  - `mkdir -p "$FRAMES_DIR" "$OUTPUT_DIR"`
- Acquire frames from FTP (example):
  - `zyra acquire ftp "ftp://${FTP_HOST}${FTP_PATH}" --sync-dir "$FRAMES_DIR" --since-period "$SINCE_PERIOD" --pattern "$PATTERN" --date-format "$DATE_FORMAT"`
- Validate frames and write metadata:
  - `zyra transform metadata --frames-dir "$FRAMES_DIR" --pattern "$PATTERN" --datetime-format "$DATE_FORMAT" --period-seconds "$PERIOD_SECONDS" --output "$FRAMES_DIR/metadata/frames-meta.json"`
- Compose the video:
  - With basemap: `zyra visualize compose-video --frames "$FRAMES_DIR" --output "$OUTPUT_PATH" --basemap "$BASEMAP_IMAGE"`
  - No basemap: `zyra visualize compose-video --frames "$FRAMES_DIR" --output "$OUTPUT_PATH"`
  - Verify output: `ls -lh "$OUTPUT_PATH" && (cd "$OUTPUT_DIR" && sha256sum "$DATASET_NAME.mp4" > "$DATASET_NAME.mp4.sha256")`
- Optional: Upload to Vimeo (requires creds):
  - `zyra decimate vimeo --input "$OUTPUT_PATH" --replace-uri "$VIMEO_URI"`
- Optional: Update S3 dataset.json (requires AWS creds and S3_URL):
  - `zyra acquire s3 --url "$S3_URL" --output "$FRAMES_DIR/metadata/dataset.json.bak"`
  - `zyra transform update-dataset-json --input-url "$S3_URL" --dataset-id "$DATASET_ID" --meta "$FRAMES_DIR/metadata/frames-meta.json" --vimeo-uri "$VIMEO_URI" --output - | zyra decimate s3 --read-stdin --url "$S3_URL"`

Debug logging
- Set `ZYRA_VERBOSITY` in CI/CD Variables or the Run Pipeline form:
  - `debug`: verbose logging (includes ffmpeg output and detailed steps). Also adds `-v` to all `zyra` CLI calls in CI.
  - `info`: default logging (general progress and summaries).
  - `quiet`: errors only (suppresses most logs).

Tips
- To speed up first runs, temporarily set `SINCE_PERIOD=P30D` (or smaller) in the dataset env.
- If compose fails or produces no file, list the output dir (`ls -la "$OUTPUT_DIR"`) and confirm frames matched the `PATTERN` under `$FRAMES_DIR`.
- Basemap must be readable inside the container; supply a full path if it isn’t bundled in the image.
- Clean state: `rm -rf _work/` to remove cached frames/outputs.

## Datasets
- See `datasets/README.md` for the full `.env` schema, examples, and CI behavior.
- Place per‑dataset environment files in `datasets/`, named `<name>.env` (e.g., `drought.env`). These are sourced by CI jobs. Typical keys:
  - `DATASET_ID`: unique SOS identifier for the dataset.
  - `FTP_HOST` and `FTP_PATH`: remote source for frames.
  - `VIMEO_URI`: Vimeo video resource to replace.
  - `SINCE_PERIOD`, `PERIOD_SECONDS`: temporal window and cadence.
  - `PATTERN`, `DATE_FORMAT`: filename and timestamp parsing.

## Notes
- Prefer immutable tags or pin by digest for reliability in CI. Avoid mutating tags in place.
