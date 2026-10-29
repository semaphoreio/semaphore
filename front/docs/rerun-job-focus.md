# Rerun job visibility (#1239)

## Objective and interaction

The workflow diagram offers **All jobs / This run** when a pipeline includes
reused jobs. All jobs is the default. This run replaces reused job rows with
per-block counts while keeping block headers and dependency edges. Returning
to All jobs restores the original rows and job links.

The controls are native buttons with an exposed selected state, a visible
keyboard focus indicator, and a screen-reader status announcement. They share
a rounded segmented track and Semaphore's existing small-button typography.
The selected surface slides over 160ms; reduced-motion preferences disable
the transition. Choices are
independent per pipeline, survive polling replacements, and reset when leaving
the workflow. The existing skipped-block control continues to work.

This interaction is a proposal for the upstream `solution-tbd` issue; it has
not been approved by Semaphore maintainers.

## Data model

Job status and execution provenance are separate. A passed job can belong to
this run; passing alone never makes it reused. `PipelineView.job_counts/1`
classifies jobs using the same individual-job and whole-block lineage as the
rendered rows. Skipped jobs are counted separately, never as current-run execution. Topology-only
placeholders belong to this run until actual job data is available.

The Preact control receives a pipeline ID and typed `JobCounts` with
`currentRun`, `reused`, and `skipped` fields. All jobs counts the full pipeline;
This run excludes reused and skipped jobs from its count. These are view data, not new stored state or
an API endpoint. Page-scoped visibility choices live outside polled fragments.
The existing custom-element integration handles component disconnection;
Turbo page teardown clears the choices.

Filtering uses a disposable copy of the server-rendered block HTML, whose
`.job-reused` markers already encode authoritative lineage. The serialized
graph data stays unchanged. The existing graph renderer recalculates layout,
and successor margins are updated after the user changes visibility.

## Implementation and style

The small model and component live in `assets/js/workflow_view/`, next to the
graph renderer, with colocated Mocha tests. The backend helper and ExUnit
tests follow the existing view conventions. Reuse Preact, preactement, the
existing button styles, and graph layout; do not introduce a second framework.

## Verification

From `front/assets/`:

```sh
TZ=UTC npm test
npm run lint
npx tsc --noEmit
npm run build:assets
```

With the Docker development stack available, also run from `front/`:

```sh
make test.ex TEST_FILE='test/front_web/views/pipeline_view_test.exs'
make format.ex
make lint.ex
make test.ex TEST_FILE='test/browser/**/*.exs test/browser/*.exs'
```

Verify keyboard selection, polling updates, independent pipeline choices,
skipped-block toggling, current-run successes, pending jobs, fully reused
blocks, graph compaction, and restoration of original links. The feature
changes visibility only: it never triggers reruns or changes job records.
