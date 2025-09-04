# Repository Guidelines

## Project Structure & Module Organization
- `datasets/`: Per‑dataset env files (e.g., `drought.env`); see `datasets/README.md`.
- `.devcontainer/`: Local containerized dev environment.
- `.github/workflows/`: GitHub Actions workflows (reusable + per‑dataset wrappers).
- `Dockerfile`, `docker-compose.yml`: Build/run images; mount host data at `/data`.
- `README.md`: Usage, credentials, CI overview, and dataset docs.

## Build, Test, and Development Commands
- Start dev container: `docker compose up --build -d`.
- Shell into container: `docker compose exec zyra-scheduler bash`.
- Lint/format (inside container): `poetry run ruff check src tests && poetry run ruff format --check src tests`.
- Run tests (inside container): `poetry run pytest -q` (coverage in CI).
- Local CLI example: if developing helpers/scripts locally, prefer `zyra` CLI inside the devcontainer or Poetry scripts in this repo as applicable.

## Coding Style & Naming Conventions
- Python, 4-space indent; prefer type hints and docstrings.
- Names: `snake_case` modules/functions, `PascalCase` classes, `UPPER_SNAKE` constants.
- CLI flags use long, hyphenated/underscored options consistent with README.
- Tooling: Ruff for lint/format; keep zero warnings locally before pushing.

## Testing Guidelines
- Framework: Pytest. Place tests under `tests/` as `test_*.py`.
- Scope: Mock FTP/Vimeo/S3; avoid real network or secrets.
- Run subsets: `pytest -k name` or specific node ids.
- CI enforces coverage; add tests for new paths and edge cases.

## Commit & Pull Request Guidelines
- Commits: imperative, concise subject (≤72 chars); reference issues (`Closes #123`).
- PRs: describe changes, link issues, add reproduction/how-to-test, and include screenshots/log excerpts if UX/output changes.
- Keep docs updated (`README.md`, `datasets/README.md`, `datasets/*.env`). All CI checks must pass.

## Security & Configuration Tips
- Never commit secrets. Provide creds via GitHub Secrets or CI/CD variables. Keep `.env` untracked.
- Do not print tokens/keys in logs. Ensure `HOST_DATA_PATH` is writable for `/data/images`, `/data/output`, and `/data/logs`.
- Prefer immutable GHCR tags or digests for CI reliability (e.g., pin `ghcr.io/noaa-gsl/zyra-scheduler@sha256:...`).

## CI/CD Overview
- Actions jobs run in `ghcr.io/noaa-gsl/zyra-scheduler` by default; override via `ZYRA_SCHEDULER_IMAGE`.
- Reusable workflow (`.github/workflows/zyra.yml`) expects `DATASET_NAME` and loads `datasets/<name>.env`.
- Example stages: `acquire` → `validate` → `compose` → `upload` → `update`.
- Caching: per‑dataset frames cached under `/data/images/${DATASET_NAME}`.
- Artifacts: key outputs uploaded via `actions/upload-artifact`.

## Architecture Overview
This repo orchestrates Docker, GitHub Actions workflows, and scheduling for example real‑time video pipelines using the `zyra` CLI. Core FTP/Vimeo/S3/video logic lives in the external `zyra` library; keep changes focused on orchestration and configuration in this repo.

## Add a Dataset (Checklist)
- Create `datasets/<name>.env` with required keys. See `datasets/README.md` for schema and an example. At minimum:
  - `DATASET_ID`, `FTP_HOST`, `FTP_PATH`, `VIMEO_URI`, `SINCE_PERIOD`, `PERIOD_SECONDS`, `PATTERN`, `DATE_FORMAT`.
  - Optional: `S3_URL` (or provide via CI/CD variable).
- Run the GitHub Actions workflow manually with `DATASET_NAME=<name>`.
  - Confirm `acquire-images` syncs frames under `/data/images/${DATASET_ID}`.
  - Confirm `validate-frames` writes `/data/images/${DATASET_ID}/metadata/frames-meta.json`.
  - Confirm `compose-video` produces `/data/output/${DATASET_ID}.mp4`.
  - Optional: `upload-vimeo` and `update-metadata` require Vimeo and AWS creds.
- Configure credentials (non-secrets in env file; secrets in CI/CD):
  - Vimeo: `VIMEO_CLIENT_ID`, `VIMEO_CLIENT_SECRET`, `VIMEO_ACCESS_TOKEN` via GitHub Secrets or your CI/CD variables.
  - AWS: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` via GitHub Secrets or CI/CD variables; `S3_URL` in the dataset env or CI.
- Set up a schedule: add or enable a cron in a per‑dataset wrapper under `.github/workflows/` and set `with: DATASET_NAME=<name>`.
- Pin the image for reliability (optional): set `ZYRA_SCHEDULER_IMAGE=ghcr.io/noaa-gsl/zyra-scheduler@sha256:<digest>` in CI/CD variables or schedule.
