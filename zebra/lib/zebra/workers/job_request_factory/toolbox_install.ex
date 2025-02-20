defmodule Zebra.Workers.JobRequestFactory.ToolboxInstall do
  alias Zebra.Workers.JobRequestFactory.JobRequest

  def env_vars(job) do
    [
      JobRequest.env_var(
        "SEMAPHORE_TOOLBOX_METRICS_ENABLED",
        to_string(!Zebra.Models.Job.self_hosted?(job.machine_type))
      )
    ]
  end
end
