import Config

config :zebra, Zebra.QuantumScheduler,
  jobs: [
    # Measure job states every minute.
    {"* * * * *", {Zebra.Monitor, :count_pending_jobs, []}},
    {"* * * * *", {Zebra.Monitor, :count_enqueued_jobs, []}},
    {"* * * * *", {Zebra.Monitor, :count_scheduled_jobs, []}},
    {"* * * * *", {Zebra.Monitor, :count_waiting_for_agent_jobs, []}},
    {"* * * * *", {Zebra.Monitor, :count_started_jobs, []}},

    # measure waiting times every minute.
    {"* * * * *", {Zebra.Monitor, :waiting_times, []}},

    # Measure task and job_stop_requests every minute.
    {"* * * * *", {Zebra.Monitor, :count_pending_job_stop_requests, []}},
    {"* * * * *", {Zebra.Monitor, :count_running_tasks, []}},

    # Every 5 minutes, these checks are more expensive.
    {"*/5 * * * *", {Zebra.Monitor, :count_stuck_jobs, []}},
    {"*/5 * * * *", {Zebra.Monitor, :count_inconsistent_jobs, []}},

    # Stop jobs on suspended orgs.
    {"*/5 * * * *", {Zebra.Monitor, :stop_jobs_on_suspended_orgs, []}}
  ]
