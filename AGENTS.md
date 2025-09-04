# Repository Guidelines

## Project Structure & Module Organization
- `datasets/`: Per‑dataset env files (e.g., `drought.env`); see `datasets/README.md`.
- `.devcontainer/`: Local containerized dev environment.
- `.gitlab-ci.yml`: CI pipeline (stages and jobs inline).
- `Dockerfile`, `docker-compose.yml`: Build/run images; mount host data at `/data`.
- `README.md`: Usage, credentials, CI overview, and dataset docs.

## Build, Test, and Development Commands
- Start dev container: `docker compose up --build -d`.
- Shell into container: `docker compose exec rtvideo bash`.
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
- Never commit secrets. Provide creds via CI/CD variables or `$HOME/.rtvideo/credentials`. Keep `.env` untracked.
- Do not print tokens/keys in logs. Ensure `HOST_DATA_PATH` is writable for `/data/images`, `/data/output`, and `/data/logs`.
- Prefer immutable GHCR tags or digests for CI reliability (e.g., pin `ghcr.io/noaa-gsl/zyra-scheduler@sha256:...`).

## CI/CD Overview
- Jobs run inside `ghcr.io/noaa-gsl/zyra-scheduler` (default `latest`), with entrypoint overridden to run shell scripts.
- Required variable: `DATASET_NAME` (stems from `datasets/<name>.env`). Jobs source this env file in a global `before_script`.
- Optional variable: `ZYRA_SCHEDULER_IMAGE` to override the runtime image.
- Stages: `acquire` → `validate` → `compose` → `upload` → `update`.
- Rules: jobs run when pipeline is a schedule or when `DATASET_NAME` is set. Otherwise jobs do not start.
- Caching: keyed by `${DATASET_NAME}-frames` for `/data/images/${DATASET_ID}`.
- Artifacts: frames and outputs preserved under `/data` inside the runner container.

## Architecture Overview
This repo orchestrates Docker, GitLab CI pipelines, and scheduling for real-time video. Core FTP/Vimeo/S3/video logic lives in the external `zyra` library; keep changes focused on orchestration and configuration in this repo.

## Add a Dataset (Checklist)
- Create `datasets/<name>.env` with required keys. See `datasets/README.md` for schema and an example. At minimum:
  - `DATASET_ID`, `FTP_HOST`, `FTP_PATH`, `VIMEO_URI`, `SINCE_PERIOD`, `PERIOD_SECONDS`, `PATTERN`, `DATE_FORMAT`.
  - Optional: `S3_URL` (or provide via CI/CD variable).
- Run a manual pipeline: click “Run pipeline” and set `DATASET_NAME=<name>`.
  - Confirm `acquire-images` syncs frames under `/data/images/${DATASET_ID}`.
  - Confirm `validate-frames` writes `/data/images/${DATASET_ID}/metadata/frames-meta.json`.
  - Confirm `compose-video` produces `/data/output/${DATASET_ID}.mp4`.
  - Optional: `upload-vimeo` and `update-metadata` require Vimeo and AWS creds.
- Configure credentials (non-secrets in env file; secrets in CI/CD):
  - Vimeo: `VIMEO_CLIENT_ID`, `VIMEO_CLIENT_SECRET`, `VIMEO_ACCESS_TOKEN` as CI variables or `$HOME/.rtvideo/credentials` on runners.
  - AWS: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` as CI variables or runner creds; `S3_URL` in env or CI.
- Set up a schedule: CI/CD → Schedules → New schedule; add variables `DATASET_NAME=<name>` and optionally `ZYRA_SCHEDULER_IMAGE`.
- Pin the image for reliability (optional): set `ZYRA_SCHEDULER_IMAGE=ghcr.io/noaa-gsl/zyra-scheduler@sha256:<digest>` in CI/CD variables or schedule.
