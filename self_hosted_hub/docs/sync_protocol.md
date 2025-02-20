# Coordinator pattern for communication between Self-Hosted Hub and Agents

In this communication pattern, the Agent will continuously tell the Hub what it
is doing, and receive instructions from the Hub what to do next.

Example communication flow:

```
@ 00:00

  Hub  <--- POST /api/v1/self_hosted_agents/sync  {"state": "waiting-for-jobs"}
       ---> {"action": "continue"}

@ 00:05

  Hub  <--- POST /api/v1/self_hosted_agents/sync  {"state": "waiting-for-jobs"}
       ---> {"action": "continue"}

@ 00:10

  Hub  <--- POST /api/v1/self_hosted_agents/sync  {"state": "waiting-for-jobs"}
       ---> {"action": "run-job", "job-id": "<job-id>"}

  Hub  <--- GET /api/v1/self_hosted_agents/job/payload/<job-id>
       ---> {commands: ...}

@ 00:15

  Hub  <--- POST /api/v1/self_hosted_agents/sync  {"state": "running-job", "job_id": <job-id>}
       ---> {"action": "continue"}

@ 00:20

  Hub  <--- POST /api/v1/self_hosted_agents/sync  {"state": "finished-job"}
       ---> {"action": "wait-for-jobs"}

@ 00:25

  Hub  <--- POST /api/v1/self_hosted_agents/sync  {"state": "waiting-for-jobs"}
       ---> {"action": "continue"}
```

### How this pattern compares to others?

**Compared to Thermostat pattern**

The thermostat pattern is ideal for setting up a state on the coordinator, and
the agents follows it. The tricky part is that in case of a finished jobs, the
Agent is the one who is deciding on that state change, not the Hub. The problem
is not impossible to solve, but it breaks the nice and tidy idea of the
thermostat pattern.

**Compared to an Event Queue pattern**

In the event queue pattern, the Agent is fetching events from an event queue on
the backend. This queue could be based on RabbitMQ in the backend, and hence
be very optimal on the resources.

However, some cases are trickier to implement. For example, if the agent gets
this series of events: [run job <id1>, stop job <id2>, run job <id3>], then
ideally the Agent should skip the first two events, and jump straight to the
last one. This complicates the model.

**Lack of built in error reporting**

In both models the Hub is not aware in which state is the Agent. This reduces
the observability capabilities of the backend, capabilities that could be used
for setting up metrics and alerts.

## Communication scenarios

### Running a job

```
Hub  <--- POST /api/v1/self_hosted_agents/sync  {"state": "waiting-for-jobs"}
     ---> {"action": "continue"}

Hub  <--- POST /api/v1/self_hosted_agents/sync  {"state": "waiting-for-jobs"}
     ---> {"action": "run-job", "job-id": "<job-id>"}

Hub  <--- GET /api/v1/self_hosted_agents/job/payload/<job-id>
     ---> {commands: ...}

Hub  <--- POST /api/v1/self_hosted_agents/sync  {"state": "running-job", "job_id": <job-id>}
     ---> {"action": "continue"}

Hub  <--- POST /api/v1/self_hosted_agents/sync  {"state": "finished-job", "job_id": <job-id>}
     ---> {"action": "wait-for-jobs"}

Hub  <--- POST /api/v1/self_hosted_agents/sync  {"state": "waiting-for-jobs"}
     ---> {"action": "continue"}
```

### Stopping a job

```
Hub  <--- POST /api/v1/self_hosted_agents/sync  {"state": "waiting-for-jobs"}
     ---> {"action": "continue"}

Hub  <--- POST /api/v1/self_hosted_agents/sync  {"state": "waiting-for-jobs"}
     ---> {"action": "run-job", "job-id": "<job-id>"}

Hub  <--- GET /api/v1/self_hosted_agents/job/payload/<job-id>
     ---> {commands: ...}

Hub  <--- POST /api/v1/self_hosted_agents/sync  {"state": "running-job", "job_id": <job-id>}
     ---> {"action": "continue"}

Hub  <--- POST /api/v1/self_hosted_agents/sync  {"state": "running-job", "job_id": <job-id>}
     ---> {"action": "stop-job"}

Hub  <--- POST /api/v1/self_hosted_agents/sync  {"state": "stopping-job", "job_id": <job-id>}
     ---> {"action": "continue"}

Hub  <--- POST /api/v1/self_hosted_agents/sync  {"state": "finished-job", "job_id": <job-id>}
     ---> {"action": "wait-for-jobs"}
```

### Network problems during communication

```
Hub  <--- POST /api/v1/self_hosted_agents/sync  {"state": "waiting-for-jobs"}
     ---> 503

Hub  <--- POST /api/v1/self_hosted_agents/sync  {"state": "waiting-for-jobs"}
     ---> 503

... 10 minutes later ...
... hub declares the agent dead ...

Hub  <--- POST /api/v1/self_hosted_agents/sync  {"state": "waiting-for-jobs"}
     ---> 401

... agent stops the job and shuts down ...
```

### Token reset on the Hub

```
Hub  <--- POST /api/v1/self_hosted_agents/sync  {"state": "waiting-for-jobs"}
     ---> 401

... agent stops the job and shuts down ...
```
