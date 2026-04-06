# SharedComputing Reconstruction Plan

## Why Restructure
The repository works, but Python runtime files are currently flat at the root. That makes ownership boundaries less clear as the project grows (API control plane, training orchestration, workers, utilities, scripts, docs, and artifacts).

This plan keeps behavior unchanged while making the codebase easier to navigate, test, and package.

## Current Structure (Summary)
- Root contains most Python entry points and modules:
  - master.py
  - worker.py
  - backend_service.py
  - backend_helpers.py
  - train.py
  - train_dist.py
  - run.py
  - predict.py
- Native app code is already isolated under SharedComputingMac.
- Runtime output folder is already conceptually separated (runtime/).
- Tests exist but currently minimal (tests/test_backend_helpers.py).

## Typical Structure Used by Similar Projects
For mixed app + ML/control-plane repos, the most common stable pattern is:

1. src layout for Python code
2. explicit app/service folders (api, training, worker)
3. scripts folder for CLI entry points
4. tests mirrored by domain
5. runtime/output folders kept outside source
6. docs and operational assets in dedicated folders

A common target shape:

- src/
  - sharedcomputing/
    - api/
    - training/
    - workers/
    - telemetry/
    - core/
- scripts/
- tests/
- docs/
- runtime/
- data/

## Proposed Target Structure for This Repository

```text
SharedComputing/
|-- SharedComputingMac/                  # Native macOS client (unchanged)
|-- src/
|   `-- sharedcomputing/
|       |-- api/
|       |   |-- app.py                   # from backend_service.py
|       |   `-- schemas.py               # request/response models (optional split)
|       |-- training/
|       |   |-- master.py                # from master.py
|       |   |-- single.py                # from train.py
|       |   |-- distributed_local.py     # from train_dist.py
|       |   `-- predict.py               # from predict.py
|       |-- workers/
|       |   `-- worker.py                # from worker.py
|       |-- telemetry/
|       |   `-- system_metrics.py        # future shared telemetry helpers
|       |-- core/
|       |   |-- paths.py                 # central path constants
|       |   |-- dataset.py               # dataset resolution/counting
|       |   `-- parsing.py               # summary parsing, utility parsing
|       |-- utils/
|       |   `-- backend_helpers.py       # temporary home if core split is deferred
|       `-- __init__.py
|-- scripts/
|   |-- run_local.py                     # from run.py
|   |-- run_master.py                    # thin launcher for training/master.py
|   `-- run_worker.py                    # thin launcher for workers/worker.py
|-- tests/
|   |-- api/
|   |-- training/
|   |-- workers/
|   `-- core/
|-- docs/
|-- data/
|-- runtime/                             # generated db/logs/summaries/models
|-- Dockerfile
|-- docker-compose.yml
|-- requirements-backend.txt
|-- README.md
|-- CHANGELOG.md
`-- re-construction.md
```

## Should We Create an api Folder?
Yes.

Reason:
- backend_service.py is already acting as a control API service and orchestration boundary.
- Moving API-specific logic into an api folder clarifies separation from training internals.
- It becomes easier to add API tests, schema management, and future versioning.

Minimum first step:
- Create src/sharedcomputing/api and move backend_service.py into app.py later.
- Keep a thin compatibility launcher at the old path during transition if needed.

## Suggested Module Mapping (No Moves Yet)
- backend_service.py -> src/sharedcomputing/api/app.py
- backend_helpers.py -> src/sharedcomputing/core (or utils initially)
- master.py -> src/sharedcomputing/training/master.py
- train.py -> src/sharedcomputing/training/single.py
- train_dist.py -> src/sharedcomputing/training/distributed_local.py
- worker.py -> src/sharedcomputing/workers/worker.py
- predict.py -> src/sharedcomputing/training/predict.py
- run.py -> scripts/run_local.py

## Migration Plan (Safe, Incremental)

### Phase 1: Skeleton Only
- Create src/sharedcomputing package directories.
- Add __init__.py files.
- Do not move logic yet.

### Phase 2: Entry-Point Wrappers
- Add scripts wrappers that call existing root files.
- Keep all current commands working.

### Phase 3: Internal Moves
- Move one domain at a time (api -> training -> workers -> helpers).
- After each move, update imports and run smoke checks.

### Phase 4: Runtime/Artifacts Hygiene
- Keep generated outputs under runtime/ only.
- Avoid writing summaries/models into repo root in future revisions.

### Phase 5: Test Coverage Expansion
- Add tests per domain folder.
- Keep at least one smoke test for each launcher path.

## Operational Notes
- Do not move data/ in this step.
- Keep SharedComputingMac untouched except import/path updates if it launches Python by path.
- Use compatibility shims during migration to avoid breaking scripts and docs.

## Acceptance Criteria for the Future Refactor
- Existing training flows still run:
  - single-machine
  - local distributed
  - LAN master/worker
  - backend-controlled run flow
- Existing API endpoints remain compatible.
- Swift app can still start and control runs.
- Logs, summaries, checkpoints, and sqlite history continue to work.
- README command examples updated only after final move.
