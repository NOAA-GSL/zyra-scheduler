# Dataset .env Files

# Dataset .env Files

Quick overview of how these variables are used across the CI stages:
- acquire-images: uses `FTP_HOST`, `FTP_PATH`, `SINCE_PERIOD`, `PATTERN`, `DATE_FORMAT` to sync frames into the workspace.
- validate-frames: uses `PATTERN`, `DATE_FORMAT`, `PERIOD_SECONDS` to generate `metadata/frames-meta.json`.
- compose-video: reads frames and produces the MP4 output for the dataset.
  - If `BASEMAP_IMAGE` is set, the composer includes it (passed as `--basemap <file>`).
- upload-vimeo: uploads/replaces the video at `VIMEO_URI` (credentials from CI variables like `VIMEO_ACCESS_TOKEN`).
- update-metadata: reads `S3_URL`, merges frames/Vimeo details into dataset.json, and writes back to S3.

Each dataset has a small POSIX-compatible `.env` file in this folder named `<name>.env` (e.g., `drought.env`). The root pipeline uses the dataset name as an input (or schedule variable) and the jobs source this file inside the container to configure the run.

## Naming
- File name: `<dataset_name>.env` (example: `drought.env`). The stem (`drought`) is passed as `DATASET_NAME` when triggering the pipeline.
- `DATASET_ID`: A unique, stable identifier for the dataset used in paths and metadata (UPPER_SNAKE recommended), e.g., `INTERNAL_SOS_DROUGHT_RT`.

## Required keys
- `DATASET_ID`: Unique ID used for `/data/images/${DATASET_ID}` and output naming.
- `FTP_HOST`: FTP host name (no scheme), e.g., `ftp.nnvl.noaa.gov`.
- `FTP_PATH`: Remote path on the FTP server where frames live, e.g., `/SOS/DroughtRisk_Weekly`.
- `VIMEO_URI`: Target Vimeo video URI to replace, e.g., `/videos/900195230`.
- `SINCE_PERIOD`: ISO‑8601 duration for how far back to sync frames, e.g., `P1Y`, `P30D`, `P2W`.
- `PERIOD_SECONDS`: Frame cadence in seconds used for metadata inference, e.g., `604800` (7 days).
- `PATTERN`: Regex (quoted) that matches frame filenames, ideally anchored, e.g., `^DroughtRisk_Weekly_[0-9]{8}\.png$`.
- `DATE_FORMAT`: strptime/strftime format that parses the timestamp portion, e.g., `%Y%m%d`.

## Optional keys
- `S3_URL`: S3 URL for the dataset JSON used in the `update-metadata` stage (e.g., `s3://bucket/path/dataset.json`). If not provided here, set it as a CI/CD variable (project/group) or in the runner’s environment.
- `BASEMAP_IMAGE`: Optional basemap for compositing under frames. You can use either a plain filename (e.g., `earth_vegetation.jpg`, auto‑resolved by the Zyra CLI) or a package URL form (e.g., `pkg:zyra.assets/images/earth_vegetation.jpg`).

### Basemap examples
```
DATASET_ID=INTERNAL_SOS_FIRE_RT
FTP_HOST=public.sos.noaa.gov
FTP_PATH=/rt/fire/4096
VIMEO_URI=/videos/919356484
SINCE_PERIOD=P1Y
PERIOD_SECONDS=86400
PATTERN=^fire_[0-9]{8}\.png$
DATE_FORMAT=%Y%m%d
# Plain filename (auto‑resolved) or packaged asset reference
BASEMAP_IMAGE=earth_vegetation.jpg
# BASEMAP_IMAGE=pkg:zyra.assets/images/earth_vegetation.jpg
```

## Example (`drought.env`)
```
DATASET_ID=INTERNAL_SOS_DROUGHT_RT
FTP_HOST=ftp.nnvl.noaa.gov
FTP_PATH=/SOS/DroughtRisk_Weekly
VIMEO_URI=/videos/900195230
SINCE_PERIOD=P1Y
PERIOD_SECONDS=604800
PATTERN=^DroughtRisk_Weekly_[0-9]{8}\.png$
DATE_FORMAT=%Y%m%d
```

## How CI uses these
- The parent pipeline passes `DATASET_NAME` to the child template. Each job runs:
  - `. "datasets/${DATASET_NAME}.env"` to load these variables in the container.
- Paths and outputs:
  - Frames sync to `/data/images/${DATASET_ID}`.
  - Metadata is written to `/data/images/${DATASET_ID}/metadata/`.
  - Composed video output: `/data/output/${DATASET_ID}.mp4`.

## Tips
- Keep regexes anchored (`^...$`) to avoid accidental matches.
- Escape backslashes in `.env` strings where needed (e.g., `\.png`).
- Avoid secrets in dataset `.env` files. Provide credentials (e.g., AWS, Vimeo) via GitHub Secrets or CI/CD variables.
- Validate `DATE_FORMAT` against actual file names; it must align with the timestamp portion that `PATTERN` captures.
- Prefer immutable image tags or digests for CI reliability; keep mutable tags like `latest` for dev/test only.
