---
description: Semaphore Public API
---

# Semaphore API








This document describes all the resources that make up Semaphore API version `v1alpha`. If you have any problems or requests please [contact support](mailto:support@semaphoreci.com).

The root of the API can be found at:

- `https://<semaphore-server-url>/api/v1alpha`

For example: `https://semaphore.example.com/api/v1alpha`

## Overview

Every API request and response must satisfy the following constraints:

- All requests must use HTTPS.
- All data is sent and received as JSON.
- Blank fields are included as `null` instead of being omitted.
- Timestamps are in different formats due to the historical circumstances of how these public APIs appeared. In the next release of the API, they will be standardized. Currently, there are the following formats:
  - Unixtime Epoch time: `"create_time": "1571083003"`
  - Unixtime Epoch time with nanoseconds: `"created_at": {"seconds": 1571063401, "nanos": 559492000}`
  - Custom format: `YYYY-MM-DD HH:MM:SS.ffffffZ`, e.g.,`"2019-10-14 12:11:47.824128Z"`
  - All API requests must set the User-Agent to `SemaphoreCI v2.0 Client`.

### Authentication

All API requests require authentication. To authenticate, you need an API Token. You can find your token by visiting your [account settings](https://me.semaphore.example.com/account).

Your API Token must be sent as an HTTP header in all requests, as shown below:

```shell
curl -H "Authorization: Token {api_token}" "https://<semaphore-server-url>/api/v1alpha/{resource_name}"
```

### Errors

You can receive several errors as a response to an API request

| Error Message | Meaning |
|--|--|
| `HTTP/1.1 401 Unauthorized`| Failure to authenticate|
| `HTTP/1.1 404 Not Found` |  Resource doesn't exist or is not visible to user |

## Pagination

Every request that that returns more than 30 items will be paginated. To avoid this, you should form calls with `link` header values instead of constructing your own URLs.

A `link` header includes information about pagination, as shown below:

```text
link: <http://<semaphore-server-url>/api/v1alpha/?PAGE_PARAMS>; rel="first",
      <http://<semaphore-server-url/api/orgs?PAGE_PARAMS>; rel="next"
```

The possible `rel` values are:

- **next** - The link for the next page of results.
- **prev** - The link for the previous page of results.
- **first** - The link for the first page of results.

## Stability

There are two types of changes:

- Compatible and emergency changes may be made with no advanced notice
- Disruptive changes will not occur without advanced notice. In the event that a disruptive change is needed, a new major version will be developed
- Emergency changes happen without notice. We will, however, try to notify users as best as possible

## Compatible changes

Small in scope and unlikely to break or change semantics of existing methods.

- Adding nested resources, methods, and attributes.
- Change of documentation.
- Change of undocumented behavior.

### Disruptive changes

May have a larger impact and effort will be made to provide migration paths as needed.

- Changing semantics of existing methods.
- Removing resources, methods, and attributes.

### Emergency change

- May have larger impact, but is unavoidable due to legal compliance, security vulnerabilities, or violation of specification.

## Workflows

### Run workflow

Request:

```text
POST <semaphore-server-url>/api/v1alpha/plumber-workflows
```

Parameters:

- `project_id` (**required**) - ID of a project.
- `reference` (**required**) - git reference for the desired branch, tag, or pull request--e.g. *refs/heads/master*, *refs/tags/v1.0*, or *refs/pull/123*.
- `commit_sha` (*optional*) - Commit sha of the desired commit.
- `pipeline_file` (*optional*) - The path within the repository to the YAML file that contains the pipeline definition. The default value is *.semaphore/semaphore.yml*.

Response:

```json
HTTP status: 200

{
  "workflow_id": "32a689e0-9082-4c5b-a648-bb3dc645452d",
  "pipeline_id": "2abeb1a9-eb4a-4834-84b8-cb7806aec063",
  "hook_id": "ff7d57ef-92c5-4fcd-9c0c-6ae9e24bfcec"
}
```

Example:

```shell
curl -i -H "Authorization: Token {api_token}" \
     -d "project_id={project_id}&reference={reference}" \
     -X POST  "https://<semaphore-server-url>/api/v1alpha/plumber-workflows"
```

### Describe a workflow

Request:

```text
GET <semaphore-server-url>/api/v1alpha/plumber-workflows/:workflow_id
```

Parameters:

- `workflow_id` (**required**) - ID of a workflow.

Response:

```json
HTTP status: 200

{
  "workflow": {
    "wf_id": "72c434c4-6589-493d-97cd-22f46681c893",
    "requester_id": "d32141ca-1552-4370-b0d4-4030aa9cf524",
    "project_id": "adaede30-9de5-471f-9f95-b7d437170f10",
    "initial_ppl_id": "f86b3b5e-c3de-4f77-849f-39e080374ce4",
    "hook_id": "6d7ed9d3-3047-4d5e-9b27-f0b68b228409",
    "created_at": {
      "seconds": 1571063401,
      "nanos": 559492000
    },
    "commit_sha": "6fe03f118b7aa7b8ea1a983c3faee4f8b54213a5",
    "branch_name": "master",
    "branch_id": "e8a4ad3b-4951-4520-aed7-6292ebd70076"
  }
}
```

Example:

```shell
curl -i -H "Authorization: Token {api_token}" \
     "https://<semaphore-server-url>/api/v1alpha/plumber-workflows/:workflow_id"
```

### List workflows

Request:

```text
GET https://<semaphore-server-url>/api/v1alpha/plumber-workflows?project_id=:project_id
```

Parameters:

- `project_id` (**required**) - ID of a project.
- `branch_name` (*optional*) - Name of branch (used as a filter).
- `created_after` (*optional*) - Only workflows created after this Unix timestamp will be returned.
- `created_before` (*optional*) - Only workflows created before this Unix timestamp will be returned.

Response:

```json
HTTP status: 200

[
  {
    "wf_id": "a99a75c3-f921-4fa9-a43f-69b2cede6274",
    "triggered_by": 1,
    "rerun_of": "",
    "requester_id": "fcd7fe34-f73f-4686-821b-ce02cb970b22",
    "repository_id": "4ac16f29-43d2-4695-bd4e-d851563a350c",
    "project_id": "c394d20b-b3c6-4c90-b743-a9a65fa95a78",
    "organization_id": "f3c1a7e9-8b6d-4b1a-b1ef-7d2a4f65c931",
    "initial_ppl_id": "e1a678ba-ed2d-412f-b350-7333579bb0d3",
    "hook_id": "4a1d3cf7-c3d5-42ec-aa22-c31dffa9f05d",
    "created_at": {
      "seconds": 1570792145,
      "nanos": 544028000
    },
    "commit_sha": "cac345d0a7d425e23e18f7be33e9b441f95c65f5",
    "branch_name": "gallery",
    "branch_id": "70f52bdd-2dab-427a-81b1-d2999bc8c2a8"
  },
  {
    "wf_id": "e08a7a60-413c-4224-a208-9c67302d3ba1",
    "triggered_by": 1,
    "rerun_of": "",
    "requester_id": "fcd7fe34-f73f-4686-821b-ce02cb970b22",
    "repository_id": "4ac16f29-43d2-4695-bd4e-d851563a350c",
    "organization_id": "f3c1a7e9-8b6d-4b1a-b1ef-7d2a4f65c931",
    "project_id": "c394d20b-b3c6-4c90-b743-a9a65fa95a78",
    "initial_ppl_id": "64dc1837-aaad-4907-a7db-aedfe091a987",
    "hook_id": "84de6482-8f5b-4f31-996f-528b6d8fa771",
    "created_at": {
      "seconds": 1570715702,
      "nanos": 345824000
    },
    "commit_sha": "aa292a7a8de08bc6246de697b84d2531fc64a43b",
    "branch_name": "gallery",
    "branch_id": "70f52bdd-2dab-427a-81b1-d2999bc8c2a8"
  }
]
```

Example:

```shell
curl -i -H "Authorization: Token {api_token}" \
     "https://<semaphore-server-url>/api/v1alpha/plumber-workflows?project_id=:project_id"
```

### Rerun a workflow

```text
POST <semaphore-server-url>/api/v1alpha/plumber-workflows/:workflow_id/reschedule?request_token=:request_token
```

Parameters:

- `workflow_id` (**required**) - ID of the workflow that you want to rerun.
- `request_token` (**required**) - Idempotency token (can be any string).

Response:

```json
HTTP status: 200

{
  "wf_id": "965d3c3d-bbe6-4ff7-b62a-1ff51a92bdc0",
  "ppl_id": "6cf4569c-f76c-4dea-b293-3e4282ba1153"
}
```

Example:

```shell
curl -i -X POST -H "Authorization: Token {api_token}" \
        "https://<semaphore-server-url>/api/v1alpha/plumber-workflows/:workflow_id/reschedule\?request_token\=:request_token"
```

### Stop a workflow

```text
POST <semaphore-server-url>/api/v1alpha/plumber-workflows/:workflow_id/terminate
```

Parameters:

- `workflow_id` (**required**) - ID of the workflow that you want to stop.

Response:

```text
HTTP status: 200
```

Example:

```shell
curl -i -X POST -H "Authorization: Token {api_token}" \
        "https://<semaphore-server-url>/api/v1alpha/plumber-workflows/:workflow_id/terminate"
```

## Pipelines

### Describe a pipeline

```text
GET <semaphore-server-url>/api/v1alpha/pipelines/:pipeline_id
```

Parameters:

- `pipeline_id` (**required**) - ID of a pipeline.
- `detailed` (*optional*) - Default: `false`, which includes all information about all blocks and jobs. This option is much more expensive—if you are only interested in the status of a pipeline, don't set detailed to `true`.

Response:

```json
HTTP status: 200

{
  "pipeline": {
    "yaml_file_name": "semaphore.yml",
    "working_directory": ".semaphore",
    "wf_id": "965d3c3d-bbe6-4ff7-b62a-1ff51a92bdc0",
    "state": "done",
    "result": "passed",
    "name": "First pipeline example",
    "branch_name": "master",
    "created_at": "2019-10-14 18:31:17.293456Z"
  },
  "blocks": []
}
```

Response with `detailed=true`:

```json
HTTP status: 200

{
  "pipeline": {
    "yaml_file_name": "semaphore.yml",
    "working_directory": ".semaphore",
    "wf_id": "965d3c3d-bbe6-4ff7-b62a-1ff51a92bdc0",
    "state": "done",
    "result": "passed",
    "name": "First pipeline example",
    "branch_name": "master",
    "created_at": "2019-10-14 18:31:17.293456Z"
  },
  "blocks": [
    {
      "state": "done",
      "result": "passed",
      "name": "RSpec",
      "jobs": [
        {
          "status": "FINISHED",
          "result": "PASSED",
          "name": "Push results - 2/11",
          "job_id": "31094182-03bf-4e39-acfe-ed1058d7eb6c"
        }
      ]
    }
  ]
}
```

Example:

```shell
curl -i -H "Authorization: Token {api_token}" \
     "https://<semaphore-server-url>/api/v1alpha/pipelines/:pipeline_id"
```

### List pipelines

```text
GET <semaphore-server-url>/api/v1alpha/pipelines?project_id=:project_id
```

Parameters:

- `project_id` (**required, optional if** `wf_id` **is present**) - ID of a project.
- `wf_id` (**required, optional if** `project_id` **is present**) - ID of a workflow.
- `branch_name` (*optional*) - Name of a branch.
- `yml_file_path` (*optional*) - YML file that contains the pipeline definition.
- `created_after` (*optional*) - Only pipelines created after this Unix timestamp will be returned.
- `created_before` (*optional*) - Only pipelines created before this Unix timestamp will be returned.
- `done_after` (*optional*) - Only pipelines finished after this Unix timestamp will be returned.
- `done_before` (*optional*) - Only pipelines finished before this Unix timestamp will be returned.

Response:

```json
HTTP status: 200

[
  {
    "yaml_file_name": "semaphore.yml",
    "working_directory": ".semaphore",
    "wf_id": "484e263a-424a-4820-bff0-bba436c54042",
    "state": "DONE",
    "result": "FAILED",
    "name": "Pipeline",
    "branch_name": "ms/another-test-branch",
    "created_at": {
      "seconds": 1571076843,
      "nanos": 537730000
    }
  }
]
```

Example:

```shell
curl -i -H "Authorization: Token {api_token}" \
     "https://<semaphore-server-url>/api/v1alpha/pipelines?project_id=:project_id"
```

### Stop a pipeline

```text
PATCH <semaphore-server-url>/api/v1alpha/pipelines/:pipeline_id
```

Parameters:

- `pipeline_id` (**required**) - ID of a pipeline.
- `terminate_request` (**required**) - Must be set to `true`.

Response:

```text
HTTP status: 200
```

Example:

```shell
curl -i -X PATCH  -H "Authorization: Token {api_token}" \
     --header "Accept: application/json"  --header "Content-Type: application/json" \
     --data '{"terminate_request": true}' \
     "https://<semaphore-server-url>/api/v1alpha/pipelines/:pipeline_id"
```

### Validate a pipeline YAML

```text
POST <semaphore-server-url>/api/v1alpha/yaml
```

Parameters:

- `yaml_definition` (**required**) - The YAML document for the pipeline.

Response:

```json
HTTP status: 200
{"pipeline_id":"","message":"YAML definition is valid."}
```

Example:

```shell
curl -i -X POST \
        -H "Authorization: Token {api_token}" \
        -H "Content-Type: application/json" \
        --data "{\"yaml_definition\": \"$(cat .semaphore/semaphore.yml | sed 's/\"/\\\"/g')\"}" \
        "https://<semaphore-server-url>/api/v1alpha/yaml"
```

## Promotions

### List promotions

```text
GET <organization-url>.semaphoreci.com/api/v1alpha/promotions?pipeline_id=:pipeline_id
```

Parameters:

- `pipeline_id` (**required**) - ID of a pipeline.

Response:

```json
HTTP status: 200

[
  {
    "triggered_by": "Pipeline Done request",
    "status": "passed",
    "name": "production"
  }
]
```

Example:

```shell
curl -i -H "Authorization: Token {api_token}" \
     "https://<organization-url>.semaphoreci.com/api/v1alpha/promotions\?pipeline_id\=:pipeline_id"
```

### Trigger a promotion

```text
POST <organization-url>.semaphoreci.com/api/v1alpha/promotions
```

Parameters:

- `pipeline_id` (**required**) - ID of a pipeline.
- `name` (**required**) - Name of the promotion, e.g. `Production deployment`.
- `override` (*optional*) - Boolean safeguard flag that needs to be set to `true` if you want to trigger a promotion for a pipeline that has failed or is still running.
- *parameter_name* - (*optional*) - Name of the parameter used in the [parameterized promotion](../using-semaphore/promotions#parameters).

Response:

```text
HTTP status: 200
```

Example:

```shell
curl -H "Authorization: Token {api_token}"  \
     -d "name=:promotion_name&pipeline_id=:pipeline_id"  \
     -X POST  "https://<organization-url>.semaphoreci.com/api/v1alpha/promotions"
```

## Tasks {#tasks}

### Trigger a taks

[Tasks](../using-semaphore/tasks) can be triggered via the API.

To trigger a task with its default parameters:

```shell
curl -X POST --location "https://<semaphore-server-url>/api/v1alpha/tasks/{task_id}/run_now" \
    -H "Authorization: Token {api_token}" \
    -H "Content-Type: application/json"
```

You can pass any of the following options when you trigger the task:

- `branch`: (string) specify the branch where the task runs
- `pipeline_file`: (string) specify the [pipeline file](../using-semaphore/pipelines#yaml-path) to execute

The following example uses all these options:

```shell
curl -X POST --location "https://<semaphore-server-url>/api/v1alpha/tasks/{task_id}/run_now" \
    -H "Authorization: Token {api_token}" \
    -H "Content-Type: application/json" \
    -d $'{
    "branch": "master",
    "pipeline_file": ".semaphore/semaphore.yml",
    "parameters": {
        "PARAM_NAME": "PARAM_VALUE",
        "PARAM_NAME_2": "PARAM_VALUE_2"
    }
}'
```

## Jobs

### Describe a job

```text
GET <semaphore-server-url>/api/v1alpha/jobs/:job_id
```

Response:

```json
HTTP status: 200

{
  "metadata": {
    "name": "Job #1",
    "id": "bc8826bd-dbb2-4d28-8c90-7f370ce478fe",
    "create_time": "1571083003",
    "start_time": "1571083006",
    "finish_time": "1571083507"
  },
  "status": {
    "result": "STOPPED",
    "state": "FINISHED"
  }
}
```

Example:

```shell
curl -i -H "Authorization: Token {api_token}" \
     "https://<semaphore-server-url>/api/v1alpha/jobs/:job_id"
```

### Stop a job

```text
POST <semaphore-server-url>/api/v1alpha/jobs/:job_id/stop
```

Response:

```json
HTTP status: 200
```

Example:

```shell
curl -i -X POST -H "Authorization: Token {api_token}" \
     "https://<semaphore-server-url>/api/v1alpha/jobs/:job_id/stop"
```

### Get job logs

:::note

Instead of using the API to fetch job logs, you can also use [Semaphore CLI tool](./semaphore-cli#sem-logs) to perform the same action.

:::

```text
GET https://<semaphore-server-url>/api/v1alpha/logs/:job_id
```

Response:

```json
HTTP status: 200

{
  "events": [
    {
      "event": "job_started",
      "timestamp": 1719979253
    },
    {
      "event": "cmd_started",
      "timestamp": 1719979253,
      "directive": "Exporting environment variables"
    },
    {
      "event": "cmd_output",
      "timestamp": 1719979253,
      "output": "Exporting CI\n"
    },
    {
      "event": "cmd_output",
      "timestamp": 1719979253,
      "output": "Exporting DISPLAY\n"
    },
    {
      "event": "cmd_output",
      "timestamp": 1719979253,
      "output": "Exporting PAGER\n"
    },
    {
      "event": "cmd_finished",
      "timestamp": 1719979255,
      "directive": "Exporting environment variables",
      "exit_code": 0,
      "started_at": 1719979255,
      "finished_at": 1719979255
    },
    {
      "event": "job_finished",
      "timestamp": 1719979255,
      "result": "passed"
    }
  ]
}
```

Example:

```shell
curl -H "Authorization: Token {api_token}" \
     "https://<semaphore-server-url>/api/v1alpha/logs/:job_id"
```

## Self-hosted agent types

### Listing agent types

```text
GET <semaphore-server-url>/api/v1alpha/self_hosted_agent_types
```

Response:

```json
HTTP status: 200

{
  "agent_types": [
    {
      "status": {
        "total_agent_count": 0
      },
      "spec": {
        "agent_name_settings": {
          "assignment_origin": "assignment_origin_agent",
          "release_after": 0
        }
      },
      "metadata": {
        "update_time": 1644963451,
        "name": "s1-aws-small",
        "create_time": 1632129338
      }
    },
    {
      "status": {
        "total_agent_count": 0
      },
      "spec": {
        "agent_name_settings": {
          "assignment_origin": "assignment_origin_aws_sts",
          "release_after": 0,
          "aws": {
            "account_id": "1234567890",
            "role_name_patterns": "role1,role2"
          }
        }
      },
      "metadata": {
        "update_time": 1641302626,
        "name": "s1-aws-large",
        "create_time": 1638470284
      }
    }
  ]
}
```

Example:

```shell
curl -i \
  -H "Authorization: Token {api_token}" \
  "https://<semaphore-server-url>/api/v1alpha/self_hosted_agent_types"
```

### Create an agent type

```text
POST <semaphore-server-url>/api/v1alpha/self_hosted_agent_types
```

Parameters:

- `metadata.name` (**required**) - the name of the agent type to be created.
- `spec.agent_name_settings.assignment_origin` (*optional*) - the origin of the agent name assignment during its registration. The possible values are: `assignment_origin_agent` (*default*) and `assignment_origin_aws_sts`.
- `spec.agent_name_settings.release_after` (*optional*) - how long to hold the agent name after its disconnection, not allowing other agents to register with its name. By default, this is 0.
- `spec.agent_name_settings.aws.account_id` (**required** if `assignment_origin_aws_sts` is used).
- `spec.agent_name_settings.aws.role_name_patterns` (**required** if `assignment_origin_aws_sts` is used) - comma-separated list of AWS role names. Wildcards (*) can be used too.

Response:

```json
HTTP status: 200

{
  "metadata": {
    "update_time": 1668626650,
    "name": "s1-aws-small",
    "create_time": 1668626650
  },
  "spec": {
    "agent_name_settings": {
      "assignment_origin": "assignment_origin_aws_sts",
      "release_after": 0,
      "aws": {
        "account_id": "1234567890",
        "role_name_patterns": "role1,role2,role3*"
      }
    }
  },
  "status": {
    "total_agent_count": 0,
    "registration_token": "..."
  }
}
```

Example:

```shell
curl -i \
  -H "Authorization: Token {api_token}" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  --data '{"metadata": {"name": "s1-aws-small"}, "spec": {"agent_name_settings": {"assignment_origin": "assignment_origin_agent", "release_after": 0}}}' \
  "https://<semaphore-server-url>/api/v1alpha/self_hosted_agent_types"
```

### Update an agent type

```text
PATCH <semaphore-server-url>/api/v1alpha/self_hosted_agent_types/:agent_type_name
```

Parameters:

- `agent_type_name` (**required**) - the name of the agent type to describe.

Request body:

The request body should be a JSON object, encapsulating details about the agent type to be updated. The available fields are the same as those for creating an agent type.

Response:

```json
HTTP status: 200

{
  "metadata": {
    "update_time": 1668626650,
    "name": "s1-aws-small",
    "create_time": 1668626650
  },
  "spec": {
    "agent_name_settings": {
      "assignment_origin": "assignment_origin_aws_sts",
      "release_after": 0,
      "aws": {
        "account_id": "1234567890",
        "role_name_patterns": "role1,role2,role3*"
      }
    }
  },
  "status": {
    "total_agent_count": 0
  }
}
```

Example:

```shell
curl -X PATCH -i \
  -H "Authorization: Token {api_token}" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  --data '{"metadata": {"name": "s1-aws-small"}, "spec": {"agent_name_settings": {"assignment_origin": "assignment_origin_agent", "release_after": 0}}}' \
  "https://<semaphore-server-url>/api/v1alpha/self_hosted_agent_types/s1-aws-small"
```

### Describe an agent type

```text
GET <semaphore-server-url>/api/v1alpha/self_hosted_agent_types/:agent_type_name
```

Parameters:

- `agent_type_name` (**required**) - the name of the agent type to describe.

Response:

```json
HTTP status: 200

{
  "status": {
    "total_agent_count": 0
  },
  "spec": {
    "agent_name_settings": {
      "assignment_origin": "assignment_origin_agent",
      "release_after": 0
    }
  },
  "metadata": {
    "update_time": 1644963451,
    "name": "s1-aws-small",
    "create_time": 1632129338
  }
}
```

Example:

```shell
curl -i \
  -H "Authorization: Token {api_token}" \
  "https://<semaphore-server-url>/api/v1alpha/self_hosted_agent_types/s1-aws-small"
```

### Delete an agent type

```text
DELETE <semaphore-server-url>/api/v1alpha/self_hosted_agent_types/:agent_type_name
```

Parameters:

- `agent_type_name` (**required**) - the name of the agent type to delete.

Response:

```json
HTTP status: 200
{}
```

Example:

```shell
curl -i -X DELETE \
  -H "Authorization: Token {api_token}" \
  "https://<semaphore-server-url>/api/v1alpha/self_hosted_agent_types/s1-aws-small"
```

### Disable agents for an agent type

```text
POST <semaphore-server-url>/api/v1alpha/self_hosted_agent_types/:agent_type_name/disable_all
```

Parameters:

- `agent_type_name` (**required**) - the name of the agent type to disable agents for.
- `only_idle` (*optional*) - a boolean flag that controls whether all agents are disabled or only idle ones. By default, this is set to `true`.

Response:

```json
HTTP status: 200
{}
```

Example:

```shell
curl -i \
  -H "Authorization: Token {api_token}" \
  -d 'only_idle=false' \
  "https://<semaphore-server-url>/api/v1alpha/self_hosted_agent_types/s1-aws-small/disable_all"
```

## Organization members

### List members

```text
GET <organization-url>.semaphoreci.com/api/v1alpha/members?member_type=:member_type&page_no=:page_no&page_size=:page_size
```

Parameters:

- `member_type` (*optional*) - filter by subject type. One of `user`, `service_account`, or `group`. If omitted, only human users are returned.
- `page_no` (*optional*) - the page number to return. By default, this is 0.
- `page_size` (*optional*) - the number of members to return per page. By default, this is 2000.

Response:

```json
HTTP status: 200

{
  "members": [
    {
      "id": "e18b1526-2c2a-4ac7-9e7e-4c6f130e9a11",
      "subject_type": "user",
      "name": "Jane Doe",
      "roles": [
        {
          "role_id": "0b45cf14-2b7f-4bde-9a2c-df6b6cc35b13",
          "role_name": "Admin",
          "source": "manually"
        }
      ]
    }
  ],
  "total_pages": 1
}
```

Example:

```shell
curl -H "Authorization: Token {api_token}" \
     "https://<organization-url>.semaphoreci.com/api/v1alpha/members?member_type=user"
```

### Invite a member

```text
POST <organization-url>.semaphoreci.com/api/v1alpha/members
```

Parameters:

- `provider` (**required**) - the SCM provider the invitee's handle belongs to. One of `github`, `bitbucket`, or `gitlab`.
- `handle` (**required**) - the invitee's SCM handle (username).
- `uid` (**required** if `provider` is `bitbucket`) - the invitee's Bitbucket user id. Bitbucket accounts can't be resolved by handle alone.
- `role_id` (*optional*) - the organization role to grant on invite. If omitted, the invitee keeps the default `Member` role.
- `name` (*optional*) - the invitee's display name.
- `email` (*optional*) - the invitee's email address.

The invite always succeeds (HTTP 200) once the person is added as a collaborator, even if the requested role could not be granted right away. Check `role.status` in the response:

- `assigned` - the role was granted immediately.
- `pending` - the invitee doesn't have a Semaphore account yet, so the role couldn't be resolved. It's applied once they sign in.
- `denied` - the invitee already has a Semaphore account, but the role couldn't be granted (for example, the requester doesn't hold that role themselves).
- `defaulted_to_member` - no `role_id` was requested, so the invitee keeps the default `Member` role.

Response:

```json
HTTP status: 200

{
  "member": {
    "email": "jane@example.com",
    "name": "Jane Doe",
    "provider": "github",
    "handle": "janedoe",
    "uid": "",
    "user_id": "e18b1526-2c2a-4ac7-9e7e-4c6f130e9a11"
  },
  "role": {
    "role_id": "0b45cf14-2b7f-4bde-9a2c-df6b6cc35b13",
    "applied": true,
    "status": "assigned"
  }
}
```

Example:

```shell
curl -H "Authorization: Token {api_token}" \
     -H "Content-Type: application/json" \
     --data '{"provider": "github", "handle": "janedoe", "role_id": "0b45cf14-2b7f-4bde-9a2c-df6b6cc35b13"}' \
     "https://<organization-url>.semaphoreci.com/api/v1alpha/members"
```

### Assign a member's role

```text
PUT <organization-url>.semaphoreci.com/api/v1alpha/members/:subject_id/role
```

Parameters:

- `subject_id` (**required**) - the id of the member (user, group, or service account) to update.
- `role_id` (**required**) - the id of the role to assign.

This is an upsert - it assigns the role if the member has none yet, or changes it if they already have one.

Response:

```json
HTTP status: 200

{
  "status": "assigned"
}
```

Example:

```shell
curl -X PUT -i \
     -H "Authorization: Token {api_token}" \
     -H "Content-Type: application/json" \
     --data '{"role_id": "0b45cf14-2b7f-4bde-9a2c-df6b6cc35b13"}' \
     "https://<organization-url>.semaphoreci.com/api/v1alpha/members/e18b1526-2c2a-4ac7-9e7e-4c6f130e9a11/role"
```

### Remove a member

```text
DELETE <organization-url>.semaphoreci.com/api/v1alpha/members/:subject_id
```

Parameters:

- `subject_id` (**required**) - the id of the member to remove from the organization.

This removes the person from the organization entirely, not just a single role. Since that's their last role binding, it cascades: the member is also removed from any groups and loses every project and organization role binding.

Response:

```json
HTTP status: 200

true
```

Example:

```shell
curl -X DELETE -i \
     -H "Authorization: Token {api_token}" \
     "https://<organization-url>.semaphoreci.com/api/v1alpha/members/e18b1526-2c2a-4ac7-9e7e-4c6f130e9a11"
```

## Roles

### List roles

```text
GET <organization-url>.semaphoreci.com/api/v1alpha/roles
```

Response:

```json
HTTP status: 200

{
  "roles": [
    {
      "id": "0b45cf14-2b7f-4bde-9a2c-df6b6cc35b13",
      "name": "Admin",
      "org_id": "2b4e4c0f-c760-4f47-9dc4-b3e84f993f63",
      "scope": "org",
      "description": "Organization administrator",
      "permissions": [
        "organization.people.view",
        "organization.people.manage"
      ],
      "readonly": true
    }
  ]
}
```

Example:

```shell
curl -H "Authorization: Token {api_token}" \
     "https://<organization-url>.semaphoreci.com/api/v1alpha/roles"
```

### Describe a role

```text
GET <organization-url>.semaphoreci.com/api/v1alpha/roles/:role_id
```

Parameters:

- `role_id` (**required**) - the id of the role to describe.

Response:

```json
HTTP status: 200

{
  "id": "0b45cf14-2b7f-4bde-9a2c-df6b6cc35b13",
  "name": "Admin",
  "org_id": "2b4e4c0f-c760-4f47-9dc4-b3e84f993f63",
  "scope": "org",
  "description": "Organization administrator",
  "permissions": [
    "organization.people.view",
    "organization.people.manage"
  ],
  "readonly": true
}
```

Example:

```shell
curl -H "Authorization: Token {api_token}" \
     "https://<organization-url>.semaphoreci.com/api/v1alpha/roles/0b45cf14-2b7f-4bde-9a2c-df6b6cc35b13"
```

### Create a role

```text
POST <organization-url>.semaphoreci.com/api/v1alpha/roles
```

Parameters:

- `name` (**required**) - the name of the role.
- `description` (*optional*) - a description of the role.
- `scope` (*optional*) - `org` (*default*) or `project`.
- `permissions` (*optional*) - a list of permission **names** to grant (for example `organization.people.view`), not the permission ids returned by `GET /permissions`.

Response:

```json
HTTP status: 200

{
  "id": "88f3a2b6-4b4e-4a5f-8c2f-6f1e3a2b7c9d",
  "name": "Release manager",
  "org_id": "2b4e4c0f-c760-4f47-9dc4-b3e84f993f63",
  "scope": "org",
  "description": "Can manage deployments",
  "permissions": [
    "organization.people.view"
  ],
  "readonly": false
}
```

Example:

```shell
curl -H "Authorization: Token {api_token}" \
     -H "Content-Type: application/json" \
     --data '{"name": "Release manager", "description": "Can manage deployments", "scope": "org", "permissions": ["organization.people.view"]}' \
     "https://<organization-url>.semaphoreci.com/api/v1alpha/roles"
```

### Update a role

```text
PATCH <organization-url>.semaphoreci.com/api/v1alpha/roles/:role_id
```

Parameters:

- `role_id` (**required**) - the id of the role to update.
- `name` (*optional*) - new name for the role.
- `description` (*optional*) - new description for the role.
- `scope` (*optional*) - `org` or `project`.
- `permissions` (*optional*) - a list of permission **names** (not ids) that replaces the role's current permissions.

Fields left out of the request keep their current value.

Response:

```json
HTTP status: 200

{
  "id": "88f3a2b6-4b4e-4a5f-8c2f-6f1e3a2b7c9d",
  "name": "Release manager",
  "org_id": "2b4e4c0f-c760-4f47-9dc4-b3e84f993f63",
  "scope": "org",
  "description": "Can manage deployments and view members",
  "permissions": [
    "organization.people.view",
    "organization.people.manage"
  ],
  "readonly": false
}
```

Example:

```shell
curl -X PATCH -i \
     -H "Authorization: Token {api_token}" \
     -H "Content-Type: application/json" \
     --data '{"description": "Can manage deployments and view members", "permissions": ["organization.people.view", "organization.people.manage"]}' \
     "https://<organization-url>.semaphoreci.com/api/v1alpha/roles/88f3a2b6-4b4e-4a5f-8c2f-6f1e3a2b7c9d"
```

### Delete a role

```text
DELETE <organization-url>.semaphoreci.com/api/v1alpha/roles/:role_id
```

Parameters:

- `role_id` (**required**) - the id of the role to delete.

Response:

```json
HTTP status: 200

{
  "status": "deleted"
}
```

Example:

```shell
curl -X DELETE -i \
     -H "Authorization: Token {api_token}" \
     "https://<organization-url>.semaphoreci.com/api/v1alpha/roles/88f3a2b6-4b4e-4a5f-8c2f-6f1e3a2b7c9d"
```

## Permissions

### List permissions

```text
GET <organization-url>.semaphoreci.com/api/v1alpha/permissions?scope=:scope
```

Parameters:

- `scope` (*optional*) - `org` (*default*) or `project`. Returns the permissions available at that scope.

Response:

```json
HTTP status: 200

{
  "permissions": [
    {
      "id": "a1e2c3b4-5d6e-4f7a-8b9c-0d1e2f3a4b5c",
      "name": "organization.people.view",
      "description": "View organization members"
    },
    {
      "id": "b2f3d4c5-6e7f-4a8b-9c0d-1e2f3a4b5c6d",
      "name": "organization.people.manage",
      "description": "Manage organization members"
    }
  ]
}
```

Example:

```shell
curl -H "Authorization: Token {api_token}" \
     "https://<organization-url>.semaphoreci.com/api/v1alpha/permissions?scope=org"
```

## Groups

### List groups

```text
GET <organization-url>.semaphoreci.com/api/v1alpha/groups?page_no=:page_no&page_size=:page_size
```

Parameters:

- `page_no` (*optional*) - the page number to return. By default, this is 0.
- `page_size` (*optional*) - the number of groups to return per page. By default, this is 2000.

Response:

```json
HTTP status: 200

{
  "groups": [
    {
      "id": "3f9a2b7e-8c4d-4e2a-9b1f-6a7c8d9e0f12",
      "name": "Platform team",
      "description": "Owns platform infrastructure",
      "member_ids": [
        "e18b1526-2c2a-4ac7-9e7e-4c6f130e9a11"
      ]
    }
  ],
  "total_pages": 1
}
```

Example:

```shell
curl -H "Authorization: Token {api_token}" \
     "https://<organization-url>.semaphoreci.com/api/v1alpha/groups"
```

### Create a group

```text
POST <organization-url>.semaphoreci.com/api/v1alpha/groups
```

Parameters:

- `name` (**required**) - the name of the group.
- `description` (*optional*) - a description of the group.
- `member_ids` (*optional*) - a list of user ids to add to the group on creation.

Response:

```json
HTTP status: 200

{
  "id": "3f9a2b7e-8c4d-4e2a-9b1f-6a7c8d9e0f12",
  "name": "Platform team",
  "description": "Owns platform infrastructure",
  "member_ids": [
    "e18b1526-2c2a-4ac7-9e7e-4c6f130e9a11"
  ]
}
```

Example:

```shell
curl -H "Authorization: Token {api_token}" \
     -H "Content-Type: application/json" \
     --data '{"name": "Platform team", "description": "Owns platform infrastructure", "member_ids": ["e18b1526-2c2a-4ac7-9e7e-4c6f130e9a11"]}' \
     "https://<organization-url>.semaphoreci.com/api/v1alpha/groups"
```

### Update a group

```text
PATCH <organization-url>.semaphoreci.com/api/v1alpha/groups/:group_id
```

Parameters:

- `group_id` (**required**) - the id of the group to update.
- `name` (*optional*) - new name for the group.
- `description` (*optional*) - new description for the group.
- `members_to_add` (*optional*) - a list of user ids to add to the group.
- `members_to_remove` (*optional*) - a list of user ids to remove from the group.

Response:

```json
HTTP status: 200

{
  "id": "3f9a2b7e-8c4d-4e2a-9b1f-6a7c8d9e0f12",
  "name": "Platform team",
  "description": "Owns platform infrastructure and CI",
  "member_ids": [
    "e18b1526-2c2a-4ac7-9e7e-4c6f130e9a11",
    "a5d8e9f0-1b2c-4d3e-8f4a-5b6c7d8e9f01"
  ]
}
```

Example:

```shell
curl -X PATCH -i \
     -H "Authorization: Token {api_token}" \
     -H "Content-Type: application/json" \
     --data '{"members_to_add": ["a5d8e9f0-1b2c-4d3e-8f4a-5b6c7d8e9f01"]}' \
     "https://<organization-url>.semaphoreci.com/api/v1alpha/groups/3f9a2b7e-8c4d-4e2a-9b1f-6a7c8d9e0f12"
```

### Delete a group

```text
DELETE <organization-url>.semaphoreci.com/api/v1alpha/groups/:group_id
```

Parameters:

- `group_id` (**required**) - the id of the group to delete.

Response:

```json
HTTP status: 200

{
  "status": "deleted"
}
```

Example:

```shell
curl -X DELETE -i \
     -H "Authorization: Token {api_token}" \
     "https://<organization-url>.semaphoreci.com/api/v1alpha/groups/3f9a2b7e-8c4d-4e2a-9b1f-6a7c8d9e0f12"
```

## Service accounts

### List service accounts

```text
GET <organization-url>.semaphoreci.com/api/v1alpha/service_accounts?page_size=:page_size&page_token=:page_token
```

Parameters:

- `page_size` (*optional*) - the number of service accounts to return per page. By default, this is 100.
- `page_token` (*optional*) - a pagination token taken from a previous response's `next_page_token`.

Response:

```json
HTTP status: 200

{
  "service_accounts": [
    {
      "id": "7c1e9f3a-5b2d-4a8e-9c3f-1d2e3f4a5b6c",
      "name": "ci-deployer",
      "description": "Used by the deploy pipeline",
      "org_id": "2b4e4c0f-c760-4f47-9dc4-b3e84f993f63",
      "creator_id": "e18b1526-2c2a-4ac7-9e7e-4c6f130e9a11",
      "created_at": 1719979253,
      "updated_at": 1719979253,
      "deactivated": false
    }
  ],
  "next_page_token": ""
}
```

Example:

```shell
curl -H "Authorization: Token {api_token}" \
     "https://<organization-url>.semaphoreci.com/api/v1alpha/service_accounts"
```

### Create a service account

```text
POST <organization-url>.semaphoreci.com/api/v1alpha/service_accounts
```

Parameters:

- `name` (**required**) - the name of the service account.
- `description` (*optional*) - a description of the service account.

The response includes an `api_token` for the new service account. It is shown only now, and again if the token is later regenerated - store it, it can't be retrieved after that.

Response:

```json
HTTP status: 200

{
  "service_account": {
    "id": "7c1e9f3a-5b2d-4a8e-9c3f-1d2e3f4a5b6c",
    "name": "ci-deployer",
    "description": "Used by the deploy pipeline",
    "org_id": "2b4e4c0f-c760-4f47-9dc4-b3e84f993f63",
    "creator_id": "e18b1526-2c2a-4ac7-9e7e-4c6f130e9a11",
    "created_at": 1719979253,
    "updated_at": 1719979253,
    "deactivated": false
  },
  "api_token": "sa_token_1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d"
}
```

Example:

```shell
curl -H "Authorization: Token {api_token}" \
     -H "Content-Type: application/json" \
     --data '{"name": "ci-deployer", "description": "Used by the deploy pipeline"}' \
     "https://<organization-url>.semaphoreci.com/api/v1alpha/service_accounts"
```

### Describe a service account

```text
GET <organization-url>.semaphoreci.com/api/v1alpha/service_accounts/:service_account_id
```

Parameters:

- `service_account_id` (**required**) - the id of the service account to describe.

Response:

```json
HTTP status: 200

{
  "id": "7c1e9f3a-5b2d-4a8e-9c3f-1d2e3f4a5b6c",
  "name": "ci-deployer",
  "description": "Used by the deploy pipeline",
  "org_id": "2b4e4c0f-c760-4f47-9dc4-b3e84f993f63",
  "creator_id": "e18b1526-2c2a-4ac7-9e7e-4c6f130e9a11",
  "created_at": 1719979253,
  "updated_at": 1719979253,
  "deactivated": false
}
```

Example:

```shell
curl -H "Authorization: Token {api_token}" \
     "https://<organization-url>.semaphoreci.com/api/v1alpha/service_accounts/7c1e9f3a-5b2d-4a8e-9c3f-1d2e3f4a5b6c"
```

### Update a service account

```text
PATCH <organization-url>.semaphoreci.com/api/v1alpha/service_accounts/:service_account_id
```

Parameters:

- `service_account_id` (**required**) - the id of the service account to update.
- `name` (*optional*) - new name for the service account.
- `description` (*optional*) - new description for the service account.

Fields left out of the request keep their current value.

Response:

```json
HTTP status: 200

{
  "id": "7c1e9f3a-5b2d-4a8e-9c3f-1d2e3f4a5b6c",
  "name": "ci-deployer",
  "description": "Used by the release pipeline",
  "org_id": "2b4e4c0f-c760-4f47-9dc4-b3e84f993f63",
  "creator_id": "e18b1526-2c2a-4ac7-9e7e-4c6f130e9a11",
  "created_at": 1719979253,
  "updated_at": 1719980000,
  "deactivated": false
}
```

Example:

```shell
curl -X PATCH -i \
     -H "Authorization: Token {api_token}" \
     -H "Content-Type: application/json" \
     --data '{"description": "Used by the release pipeline"}' \
     "https://<organization-url>.semaphoreci.com/api/v1alpha/service_accounts/7c1e9f3a-5b2d-4a8e-9c3f-1d2e3f4a5b6c"
```

### Delete a service account

```text
DELETE <organization-url>.semaphoreci.com/api/v1alpha/service_accounts/:service_account_id
```

Parameters:

- `service_account_id` (**required**) - the id of the service account to delete.

Response:

```json
HTTP status: 200

{
  "status": "deleted"
}
```

Example:

```shell
curl -X DELETE -i \
     -H "Authorization: Token {api_token}" \
     "https://<organization-url>.semaphoreci.com/api/v1alpha/service_accounts/7c1e9f3a-5b2d-4a8e-9c3f-1d2e3f4a5b6c"
```

### Deactivate a service account

```text
POST <organization-url>.semaphoreci.com/api/v1alpha/service_accounts/:service_account_id/deactivate
```

Parameters:

- `service_account_id` (**required**) - the id of the service account to deactivate. A deactivated service account can no longer authenticate.

Response:

```json
HTTP status: 200

{
  "status": "deactivated"
}
```

Example:

```shell
curl -H "Authorization: Token {api_token}" \
     "https://<organization-url>.semaphoreci.com/api/v1alpha/service_accounts/7c1e9f3a-5b2d-4a8e-9c3f-1d2e3f4a5b6c/deactivate"
```

### Reactivate a service account

```text
POST <organization-url>.semaphoreci.com/api/v1alpha/service_accounts/:service_account_id/reactivate
```

Parameters:

- `service_account_id` (**required**) - the id of the service account to reactivate.

Response:

```json
HTTP status: 200

{
  "status": "reactivated"
}
```

Example:

```shell
curl -H "Authorization: Token {api_token}" \
     "https://<organization-url>.semaphoreci.com/api/v1alpha/service_accounts/7c1e9f3a-5b2d-4a8e-9c3f-1d2e3f4a5b6c/reactivate"
```

### Regenerate a service account's token

```text
POST <organization-url>.semaphoreci.com/api/v1alpha/service_accounts/:service_account_id/regenerate_token
```

Parameters:

- `service_account_id` (**required**) - the id of the service account whose token should be regenerated. The previous token stops working immediately.

The new `api_token` is shown only in this response - store it, it can't be retrieved after that.

Response:

```json
HTTP status: 200

{
  "api_token": "sa_token_9f8e7d6c5b4a3f2e1d0c9b8a7f6e5d4c"
}
```

Example:

```shell
curl -H "Authorization: Token {api_token}" \
     "https://<organization-url>.semaphoreci.com/api/v1alpha/service_accounts/7c1e9f3a-5b2d-4a8e-9c3f-1d2e3f4a5b6c/regenerate_token"
```

## Project members

### List project members

```text
GET <organization-url>.semaphoreci.com/api/v1alpha/projects/:project_id/members?page_no=:page_no&page_size=:page_size
```

Parameters:

- `project_id` (**required**) - the id of the project.
- `page_no` (*optional*) - the page number to return. By default, this is 0.
- `page_size` (*optional*) - the number of members to return per page. By default, this is 2000.

Response:

```json
HTTP status: 200

{
  "members": [
    {
      "id": "e18b1526-2c2a-4ac7-9e7e-4c6f130e9a11",
      "subject_type": "user",
      "name": "Jane Doe",
      "roles": [
        {
          "role_id": "1a2b3c4d-5e6f-4a7b-8c9d-0e1f2a3b4c5d",
          "role_name": "Contributor",
          "source": "manually"
        }
      ]
    }
  ]
}
```

Example:

```shell
curl -H "Authorization: Token {api_token}" \
     "https://<organization-url>.semaphoreci.com/api/v1alpha/projects/e48c5cf8-7389-4df1-9904-235c06473af1/members"
```

### Assign a project member's role

```text
PUT <organization-url>.semaphoreci.com/api/v1alpha/projects/:project_id/members/:subject_id/role
```

Parameters:

- `project_id` (**required**) - the id of the project.
- `subject_id` (**required**) - the id of the member to update.
- `role_id` (**required**) - the id of the project role to assign.

This is an upsert - it assigns the role if the member has none on this project yet, or changes it if they already have one.

Response:

```json
HTTP status: 200

{
  "status": "assigned"
}
```

Example:

```shell
curl -X PUT -i \
     -H "Authorization: Token {api_token}" \
     -H "Content-Type: application/json" \
     --data '{"role_id": "1a2b3c4d-5e6f-4a7b-8c9d-0e1f2a3b4c5d"}' \
     "https://<organization-url>.semaphoreci.com/api/v1alpha/projects/e48c5cf8-7389-4df1-9904-235c06473af1/members/e18b1526-2c2a-4ac7-9e7e-4c6f130e9a11/role"
```

### Remove a project member's role

```text
DELETE <organization-url>.semaphoreci.com/api/v1alpha/projects/:project_id/members/:subject_id/role
```

Parameters:

- `project_id` (**required**) - the id of the project.
- `subject_id` (**required**) - the id of the member whose project role should be removed.
- `role_id` (**required**) - the id of the project role to remove.

This retracts only the project role binding. It does not remove the member from the organization or from any groups.

Response:

```json
HTTP status: 200

true
```

Example:

```shell
curl -X DELETE -i \
     -H "Authorization: Token {api_token}" \
     -H "Content-Type: application/json" \
     --data '{"role_id": "1a2b3c4d-5e6f-4a7b-8c9d-0e1f2a3b4c5d"}' \
     "https://<organization-url>.semaphoreci.com/api/v1alpha/projects/e48c5cf8-7389-4df1-9904-235c06473af1/members/e18b1526-2c2a-4ac7-9e7e-4c6f130e9a11/role"
```

## Self-hosted agents

### List agents for an agent type

```text
GET <semaphore-server-url>/api/v1alpha/agents?agent_type=:agent_type&page_size=:page_size&cursor=:cursor
```

Parameters:

- `agent_type` (*optional*) - the name of the agent type to filter for. If not specified, agents for all agent types will be returned.
- `page_size` (*optional*) - the number of agents to return per page. By default, this is 200. If the current number of agents is more than the page size, the response will contain a non-empty `cursor` field.
- `cursor` (*optional*) - a cursor used to return agents for the next page.

Response:

```json
HTTP status: 200

{
  "agents": [
    {
      "status": {
        "state": "waiting_for_job"
      },
      "metadata": {
        "version": "v2.2.6",
        "type": "s1-my-type",
        "pid": 14,
        "os": "Ubuntu 20.04.6 LTS",
        "name": "JE1wNRR53A9IORQTMQhb",
        "ip_address": "XXX.XXX.XXX.XXX",
        "hostname": "myhost",
        "connected_at": 1686917254,
        "arch": "x86"
      }
    },
    {
      "status": {
        "state": "waiting_for_job"
      },
      "metadata": {
        "version": "v2.2.6",
        "type": "s1-my-type",
        "pid": 14,
        "os": "Ubuntu 20.04.6 LTS",
        "name": "tE77rxu2gHy2clIe4tHV",
        "ip_address": "XXX.XXX.XXX.XXX",
        "hostname": "myhost",
        "connected_at": 1686917261,
        "arch": "x86"
      }
    }
  ],
  "cursor": ""
}
```

Example:

```shell
curl -i \
  -H "Authorization: Token {api_token}" \
  "https://<semaphore-server-url>/api/v1alpha/agents"
```

### Describe an agent

```text
GET <semaphore-server-url>/api/v1alpha/agents/:agent_name
```

Parameters:

- `agent_name` (**required**) - the name of the agent to describe.

Response:

```json
HTTP status: 200

{
  "status": {
    "state": "waiting_for_job"
  },
  "metadata": {
    "version": "v2.2.6",
    "type": "s1-my-type",
    "pid": 14,
    "os": "Ubuntu 20.04.6 LTS",
    "name": "tE77rxu2gHy2clIe4tHV",
    "ip_address": "XXX.XXX.XXX.XXX",
    "hostname": "myhost",
    "connected_at": 1686917261,
    "arch": "x86"
  }
}
```

Example:

```shell
curl -i \
  -H "Authorization: Token {api_token}" \
  "https://<semaphore-server-url>/api/v1alpha/agents/{agent_name}"
```

## Deployment targets

### List targets

This API endpoint provides a list of deployment targets linked to a given project.

```text
GET <organization-url>.semaphoreci.com/api/v1alpha/deployment_targets?project_id=:project_id
```

Parameters:

- `project_id` (**required**) - UUID of the project for which deployment targets are to be listed.

Response:

The response is a JSON object comprising an array of deployment target objects for the specified project ID.

```json
HTTP status: 200

[
  {
    "url": "project_1234.zyx",
    "updated_by": "02984c87-efe8-4ea1-bcac-9511a34a3df3",
    "updated_at": "2023-06-07T09:24:04.000000Z",
    "subject_rules": [
      {
        "type": "ANY",
        "subject_id": ""
      }
    ],
    "state_message": "",
    "state": "USABLE",
    "project_id": "a426b4db-1919-483d-926d-06ba1320b209",
    "organization_id": "7304b7f9-7482-46d4-9b95-3cd5a6ef2e6f",
    "object_rules": [
      {
        "type": "BRANCH",
        "pattern": "",
        "match_mode": "ALL"
      },
      {
        "type": "TAG",
        "pattern": "",
        "match_mode": "ALL"
      },
      {
        "type": "PR",
        "pattern": "",
        "match_mode": "ALL"
      }
    ],
    "name": "DTName123",
    "last_deployment": null,
    "id": "e79d3d1c-61cc-4e07-ba32-f86694f5e80d",
    "description": "DT description",
    "created_by": "02984c87-efe8-4ea1-bcac-9511a34a3df3",
    "created_at": "2023-06-01T10:07:36.000000Z",
    "bookmark_parameter3": "",
    "bookmark_parameter2": "",
    "bookmark_parameter1": "",
    "active": true
  }
]
```

Example:

```shell
curl -i -H "Authorization: Token {api_token}" \
     "https://<organization-url>.semaphoreci.com/api/v1alpha/deployment_targets?project_id=:project_id"
```

### Describe a target

This API endpoint retrieves the details about a deployment target specified by its UUID.

```text
GET <organization-url>.semaphoreci.com/api/v1alpha/deployment_targets/:target_id
```

Parameters:

- `target_id` (**required**) - The UUID of the deployment target.

Response:

```json
HTTP status: 200

{
  "url": "project_1234.zyx",
  "updated_by": "02984c87-efe8-4ea1-bcac-9511a34a3df3",
  "updated_at": "2023-06-07T09:24:04.000000Z",
  "subject_rules": [
    {
      "type": "ANY",
      "subject_id": ""
    }
  ],
  "state_message": "",
  "state": "USABLE",
  "project_id": "a426b4db-1919-483d-926d-06ba1320b209",
  "organization_id": "7304b7f9-7482-46d4-9b95-3cd5a6ef2e6f",
  "object_rules": [
    {
      "type": "BRANCH",
      "pattern": "",
      "match_mode": "ALL"
    },
    {
      "type": "TAG",
      "pattern": "",
      "match_mode": "ALL"
    },
    {
      "type": "PR",
      "pattern": "",
      "match_mode": "ALL"
    }
  ],
  "name": "DTName123",
  "last_deployment": null,
  "id": "e79d3d1c-61cc-4e07-ba32-f86694f5e80d",
  "description": "DT description",
  "created_by": "02984c87-efe8-4ea1-bcac-9511a34a3df3",
  "created_at": "2023-06-01T10:07:36.000000Z",
  "bookmark_parameter3": "",
  "bookmark_parameter2": "",
  "bookmark_parameter1": "",
  "active": true
}
```

Example:

```shell
curl -i -H "Authorization: Token {api_token}" \
     "https://<organization-url>.semaphoreci.com/api/v1alpha/deployment_targets/:target_id"
```

#### Describe by name and project UUID

This API endpoint retrieves a deployment target based on its name and the UUID of the project it is linked to.

```text
GET <organization-url>.semaphoreci.com/api/v1alpha/deployment_targets?project_id=:project_id&target_name=:target_name
```

Parameters:

- `project_id` (**required**) - The UUID of the project to which the deployment target is linked.
- `target_name` (**required**) - The name of the deployment target.

Response:

```json
HTTP status: 200

[
  {
    "url": "project_1234.zyx",
    "updated_by": "02984c87-efe8-4ea1-bcac-9511a34a3df3",
    "updated_at": "2023-06-07T09:24:04.000000Z",
    "subject_rules": [
      {
        "type": "ANY",
        "subject_id": ""
      }
    ],
    "state_message": "",
    "state": "USABLE",
    "project_id": "a426b4db-1919-483d-926d-06ba1320b209",
    "organization_id": "7304b7f9-7482-46d4-9b95-3cd5a6ef2e6f",
    "object_rules": [
      {
        "type": "BRANCH",
        "pattern": "",
        "match_mode": "ALL"
      },
      {
        "type": "TAG",
        "pattern": "",
        "match_mode": "ALL"
      },
      {
        "type": "PR",
        "pattern": "",
        "match_mode": "ALL"
      }
    ],
    "name": "DTName123",
    "last_deployment": null,
    "id": "e79d3d1c-61cc-4e07-ba32-f86694f5e80d",
    "description": "DT description",
    "created_by": "02984c87-efe8-4ea1-bcac-9511a34a3df3",
    "created_at": "2023-06-01T10:07:36.000000Z",
    "bookmark_parameter3": "",
    "bookmark_parameter2": "",
    "bookmark_parameter1": "",
    "active": true
  }
]
```

Example:

```shell
curl -i -H "Authorization: Token {api_token}" \
     "https://<organization-url>.semaphoreci.com/api/v1alpha/deployment_targets?project_id=:project_id&target_name=:target_name"
```

### Create a target

This API endpoint allows you to create a new deployment target and assign it to a specific project.

```text
POST <organization-url>.semaphoreci.com/api/v1alpha/deployment_targets?project_id=:project_id
```

Request Body:

The request body should be a JSON object, encapsulating details about the deployment target to be created. The available fields are as follows:

- `name` (**required**) - Unique name for the target within the project.
- `project_id` (**required**) - UUID of the project.
- `unique_token` (**required**) - Idempotency UUID token.
- `description` (*optional*) - A description of the target.
- `url` (*optional*) - The URL of the target.
- `bookmark_parameter1`, `bookmark_parameter2`, `bookmark_parameter3` (*optional*) - Bookmark parameters for filtering deployments.
- `subject_rules` (*optional*) - Configures **who** can trigger a promotion of the given deployment target

.
- `object_rules` (*optional*) - Configures **which git references** are allowed for a promotion of the given deployment target.
- `env_vars` (*optional*) - A list of environment variables.
- `files` (*optional*) - A list of files with paths and base64-encoded content.

Response:

```json
HTTP status: 200

{
  "url": "www.myurl.zyx",
  "updated_by": "02984c87-efe8-4ea1-bcac-9511a34a3df3",
  "updated_at": "2023-06-08T07:48:27.000000Z",
  "subject_rules": [
    {
      "type": "ANY",
      "subject_id": ""
    }
  ],
  "state_message": "",
  "state": "SYNCING",
  "project_id": "a426b4db-1919-483d-926d-06ba1320b209",
  "organization_id": "7304b7f9-7482-46d4-9b95-3cd5a6ef2e6f",
  "object_rules": [
    {
      "type": "BRANCH",
      "pattern": "",
      "match_mode": "ALL"
    },
    {
      "type": "TAG",
      "pattern": "",
      "match_mode": "ALL"
    },
    {
      "type": "PR",
      "pattern": "",
      "match_mode": "ALL"
    }
  ],
  "name": "testTarget",
  "last_deployment": null,
  "id": "ed25bfb6-7149-40c6-8334-4eaf11337569",
  "description": "Target description",
  "created_by": "02984c87-efe8-4ea1-bcac-9511a34a3df3",
  "created_at": "2023-06-08T07:48:27.000000Z",
  "bookmark_parameter3": "",
  "bookmark_parameter2": "",
  "bookmark_parameter1": "my book 1",
  "active": true
}
```

Example request:

```shell
curl -i -X POST -H "Authorization: Token {api_token}" \
     "https://<organization-url>.semaphoreci.com/api/v1alpha/deployment_targets?project_id=:project_id" \
     -H "Content-Type: application/json" \
     -d '<json object>' 
```

```shell
curl -XPOST <organization-url>.semaphoreci.com/api/v1alpha/deployment_targets?project_id=a426b4db-1919-483d-926d-06ba1320b209 -H "Authorization: Token {api_token}" -H "Content-Type: application/json" --data '{ "name": "testTarget", "description": "Target description", "url": "www.myurl.zyx","bookmark_parameter1": "my book 1", "unique_token": "6063dd03-ecfb-11ed-b539-0045e2f582b7",  "env_vars": [ {"name": "env1","value": "val1" }  ],  "files": [ {"path": "/etc/my.conf","content": "'"$(base64 -w 0 /home/pc/proj/someconf.conf)"'" }  ]}'
```

### Update a target

This API endpoint allows you to update an existing deployment target.

```text
PATCH <organization-url>.semaphoreci.com/api/v1alpha/deployment_targets/:target_id
```

Parameters:

- `target_id` (**required**) - UUID of the deployment target to be updated.

Request Body:

The request body should be a JSON object, encapsulating details about the deployment target to be updated. The available fields are the same as those for creating a target. The difference here is that all fields are optional.

Response:

```json
HTTP status: 200

{
  "url": "www.myurl2.zyx",
  "updated_by": "02984c87-efe8-4ea1-bcac-9511a34a3df3",
  "updated_at": "2023-06-08T08:47:53.000000Z",
  "subject_rules": [
    {
      "type": "ANY",
      "subject_id": ""
    }
  ],
  "state_message": "",
  "state": "SYNCING",
  "project_id": "a426b4db-1919-483d-926d-06ba1320b209",
  "organization_id": "7304b7f9-7482-46d4-9b95-3cd5a6ef2e6f",
  "object_rules": [
    {
      "type": "BRANCH",
      "pattern": "",
      "match_mode": "ALL"
    },
    {
      "type": "TAG",
      "pattern": "",
      "match_mode": "ALL"
    },
    {
      "type": "PR",
      "pattern": "",
      "match_mode": "ALL"
    }
  ],
  "name": "testTargetChanged",
  "last_deployment": null,
  "id": "ed25bfb6-7149-40c6-8334-4eaf11337569",
  "description": "Target description changed",
  "created_by": "02984c87-efe8-4ea1-bcac-9511a34a3df3",
  "created_at": "2023-06-08T07:48:27.000000Z",
  "bookmark_parameter3": "",
  "bookmark_parameter2": "",
  "bookmark_parameter1": "my book 1c",
  "active": true
}
```

Example:

```shell
curl -i -X PATCH -H "Authorization: Token {api_token}"  \
     "https://<organization-url>.semaphoreci.com/api/v1alpha/deployment_targets/:target_id" \
     -H "Content-Type: application/json" \
     -d '<json object>'
```

```shell
curl -X PATCH https://<organization-url>.semaphoreci.com/deployment_targets/3a9196d7-f740-4451-b8f2-9d19b10a4520 \
     -H "Authorization: Token {api_token}" \
     -d'{"name": "testTargetChanged", "description": "Target description changed", "url": "www.myurl2.zyx","bookmark_parameter1": "my book 1c", "unique_token": "6063dd03-ecfb-11ed-b539-0045e2f582b8",  "env_vars": [ {"name": "env1","value": "val2" }  ],  "files": [ {"path": "/etc/my.conf","content": "'"$(base64 -w 0 /home/pc/proje/updated.conf)"'" }]}' \
     -H "Content-Type: application/json"
```

### Delete a target

This API endpoint allows you to delete a specific deployment target.

```text
DELETE <organization-url>.semaphoreci.com/api/v1alpha/deployment_targets/:target_id?unique_token=:unique_token
```

Parameters:

- `target_id` (**required**) - The UUID of the deployment target to be deleted.
- `unique_token` (**required**) - The idempotency UUID token.

Response:

```json
HTTP status: 200

{"target_id":"38572f07-15ec-459e-a122-eefa2bd19230"}
```

Example:

```shell
curl -i -X DELETE -H "Authorization: Token {api_token}" \
     "https://<organization-url>.semaphoreci.com/api/v1alpha/deployment_targets/:target_id?unique_token=:unique_token"
```

### Deactivate a target

This API endpoint allows you to deactivate a specific deployment target.

```text
PATCH <organization-url>.semaphoreci.com/api/v1alpha/deployment_targets/:target_id/deactivate
```

Parameters:

- `target_id` (**required**) - The UUID of the deployment target to be deactivated.

Response:

```json
HTTP status: 200

{
  "target_id": "a3db05c5-4345-493d-a038-6b5f2f2ba2b5",
  "cordoned": true
}
```

Example:

```shell
curl -i -X PATCH -H "Authorization: Token {api_token}" \
     "https://<organization-url>.semaphoreci.com/api/v1alpha/deployment_targets/:target_id/deactivate"
```

### Activate a target

This API endpoint allows you to (re)activate a specific deployment target.

```text
PATCH <organization-url>.semaphoreci.com/api/v1alpha/deployment_targets/:target_id/activate
```

Parameters:

- `target_id` (**required**) - The UUID of the deployment target to be (re)activated.

Response:

```json
HTTP status: 200

{
  "target_id": "a3db05c5-4345-493d-a038-6b5f2f2ba2b5",
  "cordoned": false
}
```

Example:

```shell
curl -i -X PATCH -H "Authorization: Token {api_token}" \
     "https://<organization-url>.semaphoreci.com/api/v1alpha/deployment_targets/:target_id/activate"
```

### Retrieve deployment history

This endpoint provides the deployment history for a specific deployment target.

```text
GET <organization-url>.semaphoreci.com/api/v1alpha/deployment_targets/:target_id/history
```

Parameters:

- `target_id` (**required**) - The UUID of the deployment target for which the deployment history is being retrieved.
- `cursor_type` (*optional*) - Specifies the starting point for data retrieval. Valid values include `"FIRST"`, `"AFTER"`, and `"BEFORE"`. If not specified, `FIRST` is used, which retrieves the latest deployments.
- `cursor_value` (*optional*) - Represents the timestamp, given in UNIX microseconds, at which the cursor is positioned to retrieve deployment history. If `cursor_type` is set to `AFTER`, it retrieves the oldest deployments triggered after the `cursor_value`. If `cursor_type` is set to `BEFORE`, it retrieves the latest deployments triggered before the `cursor_value`. For the `FIRST` cursor type, this value is not required.
- `git_ref_type` (*optional*) - Filters deployments based on the git reference that triggered them, such as `branch`, `tag`, or `pr` (for pull requests).
- `git_ref_label` (*optional*) - Filters deployments based on the label of the git reference, such as the name of the branch.
- `triggered_by` (*optional*) - Filters deployments based on the entity that triggered them. To filter by the user who triggered the deployments, provide the user ID.

The response includes `cursor_before` and `cursor_after` values that allow you to navigate by moving backward or forward accordingly. The response contains at most `10` deployments.

Response:

```json
HTTP status: 200

{
  "deployments": [
    {
      "triggered_by": "02984c87-efe8-4ea1-bcac-9511a34a3df3",
      "triggered_at": "2023-05-26T10:35:00.000000Z",
      "target_name": "Production 2 deploy",
      "target_id": "410bf56b-b0dc-46d2-b939-87c88a21bb84",
      "switch_id": "8b751422-1322-4a9c-b3ab-e97c451cfbdc",
      "state_message": "",
      "state": "STARTED",
      "prev_pipeline_id": "f65a5c7a-6d69-4f3e-8251-adcae6c4d6d7",
      "pipeline_id": "bf4dcb8b-fbf3-4aab-a67f-ffc1f53d6bc8",
      "id": "4885f77e-30eb-49cb-b351-d5a637d09ed8",
      "env_vars": [
        {
          "value": "Passed message 2 as parameter",
          "name": "MESSAGE"
        }
      ]
    },
    {
      "triggered_by": "Pipeline Done request",
      "triggered_at": "2023-05-26T10:34:31.000000Z",
      "target_name": "Production deploy",
      "target_id": "410bf56b-b0dc-46d2-b939-87c88a21bb84",
      "switch_id": "8b751422-1322-4a9c-b3ab-e97c451cfbdc",
      "state_message": "",
      "state":

 "STARTED",
      "prev_pipeline_id": "f65a5c7a-6d69-4f3e-8251-adcae6c4d6d7",
      "pipeline_id": "f4e1413b-2fac-4ba6-9625-921f66ef1802",
      "id": "9ef2194e-d13d-432e-8c97-c8fda64c4aa1",
      "env_vars": [
        {
          "value": "Passed message as parameter",
          "name": "MESSAGE"
        }
      ]
    }
  ],
  "cursor_before": 1685096881121173,
  "cursor_after": 0
}
```

Example:

```shell
curl -i -H "Authorization: Token {api_token}" \
     "https://<organization-url>.semaphoreci.com/api/v1alpha/deployment_targets/:target_id/history"
```

## Artifact retention policies

### Configure retention policy

This API endpoint allows you to configure the artifact retention policy for a project with the given UUID.

By default, artifacts are persisted and never automatically deleted. The artifact retention policy allows you to configure the lifetime of artifacts in your projects.

```text
POST <semaphore-server-url>/api/v1alpha/artifacts_retention_policies
```

Request Body:

The request body should be a JSON object, encapsulating details about the artifact retention policies to be configured. The available fields are as follows:

- `project_id` (**required**) - UUID of the project.
- `project_level_retention_policies` (*optional*) - List of retention rules for project-level artifacts.
- `workflow_level_retention_policies` (*optional*) - List of retention rules for workflow-level artifacts.
- `job_level_retention_policies` (*optional*) - List of retention rules for job-level artifacts.

At least one of the `project_level_retention_policies`, `workflow_level_retention_policies`, and `job_level_retention_policies` lists needs to contain valid list items for a request to be valid.

The list items for each of the retention policy fields from above should be JSON objects with the following properties:

- `selector` (**required**) - a double-star glob pattern used for identifying the artifacts paths.
- `age` (**required**) - the time after which the artifacts on the path from the `selector` field should be automatically deleted. Values should consist of a number from 1 to 12 followed by a space and one of the following: week(s), month(s), or year(s). Examples: 1 week, 2 weeks, 3 months, 4 years.

When evaluating retention policies for an artifact on a particular path, the system will iterate through the list of the policy rules and apply the first one with a selector that matches the path of that artifact.

You can find more details about artifacts retention policy in the [Artifact Retention Policies Reference](../using-semaphore/artifacts#retention).

Response:

```json
HTTP status: 200

{
  "workflow_level_retention_policies": [],
  "project_level_retention_policies": [
    {
      "selector": "/**/*",
      "age": "1 year"
    }
  ],
  "job_level_retention_policies":[
    {
      "selector": "/screenshots/**/*.png",
      "age": "2 weeks"
    },
    {
      "selector": "/logs/**/*.txt",
      "age": "3 months"
    }
  ]
}
```

Example request:

```shell
curl -X POST -H "Authorization: Token {api_token}" \
     "https://<semaphore-server-url>/api/v1alpha/artifacts_retention_policies" \
     -H "Content-Type: application/json" \
     -d '<json object>' 
```

```shell
curl -X POST -H "Authorization: Token {api_token}" \ 
     "https://<semaphore-server-url>/api/v1alpha/artifacts_retention_policies" \
     -H "Content-Type: application/json" \
     -d '{"project_id":"3796efe0-81a0-4157-8774-7ad72d41ac28","job_level_retention_policies":[{"selector":"/screenshots/**/*.png","age":"2 weeks"},{"selector":"/logs/**/*.txt","age":"3 months"}]}'
```

### Describe retention policy

This API endpoint retrieves the details about an artifacts retention policy that is configured for a project with the given UUID.

By default, projects do not have an artifacts retention policy configured so a response in this case will have a policy with an empty set of retention rules for all artifacts levels.

```text
GET <semaphore-server-url>/api/v1alpha/artifacts_retention_policies/:project_id
```

Parameters:

- `project_id` (**required**) - The UUID of the project

Response:

```json
HTTP status: 200

{
  "workflow_level_retention_policies": [],
  "project_level_retention_policies": [
    {
      "selector": "/**/*",
      "age": "1 year"
    }
  ],
  "job_level_retention_policies":[
    {
      "selector": "/screenshots/**/*.png",
      "age": "2 weeks"
    },
    {
      "selector": "/logs/**/*.txt",
      "age": "3 months"
    }
  ]
}
```

Example:

```shell
curl -i -H "Authorization: Token {api_token}" \
     "https://<semaphore-server-url>/api/v1alpha/artifacts_retention_policies/:project_id"
```
