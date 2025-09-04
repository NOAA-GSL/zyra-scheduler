# Real-Time Video Processing and Distribution System

[![pipeline status](https://gitlab.sos.noaa.gov/science-on-a-sphere/datasets/real-time-video/badges/main/pipeline.svg)](https://gitlab.sos.noaa.gov/science-on-a-sphere/datasets/real-time-video/-/commits/main)

## Overview
This repository orchestrates a real‑time video workflow using the [zyra](https://github.com/NOAA-GSL/zyra) library (FTP sync, base image → video processing, Vimeo upload, and S3 metadata updates).

## Docs & Scheduling
- Scheduling: use GitLab CI/CD pipelines and Schedules (see below).
- Contributor guide: see `AGENTS.md` for structure, style, testing, and PR guidelines.
- Local development: use `docker compose up --build -d` and `docker compose exec rtvideo bash`. The devcontainer prefers a `zyra-scheduler` base image (if provided) and layers Node.js + Codex CLI for local tooling. If none is provided, it falls back to `python:3.11-slim` for linting/tests.

### GitLab Pipelines
- Manual run: set variables in the Run pipeline form:
  - `DATASET_NAME`: dataset env file stem (e.g., `drought` for `datasets/drought.env`).
  - `ZYRA_SCHEDULER_IMAGE` (optional): container image to run jobs; defaults in the child template.
- Scheduled run: configure CI variables on the schedule:
  - `DATASET_NAME=drought`
  - `ZYRA_SCHEDULER_IMAGE=ghcr.io/noaa-gsl/zyra-scheduler:<tag-or-digest>`
- Stages: defined in `.gitlab-ci.yml` and run directly in the pipeline:
  - acquire → validate → compose → upload → update
  The jobs source `datasets/$DATASET_NAME.env` inside the container and operate under `/data`.

## Setup
- Create a `.env` from `.env.example` and set:
  - `HOST_DATA_PATH`: absolute host path for `/data` bind mount.
  - (Optional) `ZYRA_SCHEDULER_IMAGE`: fully-qualified, accessible base image that provides `/usr/local/bin/rtvideo` (e.g., your org’s GHCR/GitLab Registry tag). If you omit this or cannot access the image, the devcontainer uses `python:3.11-slim` which is sufficient for local linting and tests.

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
docker compose exec rtvideo bash
```

Security note: never commit real secrets. Keep `.env` untracked (see `.gitignore`) and set credentials via environment or your secrets store.

## Local Debugging (Dev Container)
- Enter the container:
  - `docker compose exec rtvideo bash`
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
- Acquire frames from FTP:
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

### Quick Start: Add a Dataset
- Create `datasets/<name>.env` with the required keys (see `datasets/README.md`).
- Run a manual pipeline and set variable `DATASET_NAME=<name>` to validate:
  - Acquire → frames under `/data/images/${DATASET_ID}`.
  - Validate → metadata under `/data/images/${DATASET_ID}/metadata/frames-meta.json`.
  - Compose → video at `/data/output/${DATASET_ID}.mp4`.
- Configure credentials for upload/update stages via CI/CD variables (Vimeo and AWS) or `$HOME/.rtvideo/credentials` on runners.
- Schedule it: CI/CD → Schedules → add `DATASET_NAME=<name>` (and optional `ZYRA_SCHEDULER_IMAGE`).

#### Scheduling Options (GitLab)
- Target branch: set the schedule’s target to `main` (or another branch) so it runs against that ref.
- Cron format: use standard 5-field cron in the UI.
  - Examples: `30 3 * * *` (daily 03:30), `5 12 * * 4` (Thu 12:05).
  - Timezone: pick the desired TZ in the schedule; cron is interpreted relative to this.
- Variables per schedule: add `DATASET_NAME=<env-stem>` for each dataset. Create one schedule per dataset.
  - Optionally pin the image: `ZYRA_SCHEDULER_IMAGE=ghcr.io/noaa-gsl/zyra-scheduler@sha256:<digest>` for reproducibility.
- Concurrency: enable multiple schedules as needed; jobs use per-dataset caches and won’t collide.
- Reliability tips:
  - Start with a modest `SINCE_PERIOD` (e.g., `P30D`) to seed caches faster, then widen.
  - Use pinned container digests in production schedules to avoid surprises.

### Current Datasets
The following datasets are configured in `datasets/*.env`. Suggested schedules are listed for convenience; configure CI/CD Schedules to match your needs.

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
- CI schedules: replicate the cadence/offsets above as needed using GitLab’s Scheduled Pipelines (set `DATASET_NAME=<env stem>`).

## Notes
- The CI image entrypoint is overridden so GitLab can run shell scripts inside the container. If you override images, ensure they include `zyra` and required dependencies.
- Prefer immutable tags or pin by digest for reliability in CI. Avoid mutating tags in place.
