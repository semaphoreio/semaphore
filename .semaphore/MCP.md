# Semaphore CI/CD

## ID Caching (Required)

Before using Semaphore tools, cache org and project IDs in `.semaphore/config.json`:

```json
{
  "organization_id": "<uuid>",
  "organization_name": "semaphore",
  "project_id": "<uuid>",
  "project_name": "semaphore"
}
```

Discover IDs once with `organizations_list` and `projects_list`, then always use cached values.

## Debugging Workflow

1. `workflows_search` -> find failing workflow
2. `pipelines_list` -> get pipeline from workflow
3. `pipeline_jobs` -> find failed jobs and check `result_reason`
4. If `result_reason=test`: use `get_test_results` first (structured failure data), fall back to `jobs_logs` only if no test results
5. Otherwise: use `jobs_logs` -> read error output

## Test Results

`get_test_results` returns a signed URL that **expires quickly**.

**Always:** Download once, analyze locally:
```bash
curl -s "<url>" -o /tmp/test-results.json
```

**Never:** Call get_test_results repeatedly.

## Tips

- Use `mode="summary"` to reduce response size
- Filter with `branch` and `limit` parameters
- Read `.semaphore/config.json` before each session
