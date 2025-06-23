defmodule Front.Audit.EventsDecorator do
  alias InternalApi.Audit.Event.{Medium, Operation, Resource}

  defmodule DecoratedEvent do
    use TypedStruct

    typedstruct do
      field(:description, String.t(), enforce: true)

      field(:resource, String.t(), enforce: true)
      field(:operation, String.t(), enforce: true)

      field(:user_id, String.t(), enforce: true)
      field(:username, String.t(), enforce: true)

      field(:resource_id, String.t(), enforce: true)
      field(:resource_name, String.t(), enforce: true)

      field(:medium, String.t(), enforce: true)
      field(:ip_address, String.t(), enforce: true)

      field(:timestamp, Number.t(), enforce: true)

      field(:project_id, String.t(), enforce: false)
      field(:project, Front.Models.Project.t(), enforce: false)
      field(:has_project, String.t(), enforce: false, default: false)

      field(:workflow_id, String.t(), enforce: false)
      field(:workflow, Front.Models.Workflow.t(), enforce: false)
      field(:has_workflow, String.t(), enforce: false, default: false)

      field(:pipeline_id, String.t(), enforce: false)
      field(:pipeline, Front.Models.Pipeline.t(), enforce: false)
      field(:has_pipeline, String.t(), enforce: false, default: false)

      field(:job_id, String.t(), enforce: false)
      field(:job, Front.Models.Job.t(), enforce: false)
      field(:has_job, String.t(), enforce: false, default: false)

      field(:agent, Map.t(), enforce: false)
    end
  end

  @spec decorate([InternalApi.Audit.Event.t()]) :: [__MODULE__.DecoratedEvent.t()]
  def decorate(events) do
    events
    |> construct()
    |> sort()
    |> preload_referenced_items()
  end

  @spec construct([InternalApi.Audit.Event.t()]) :: [__MODULE__.DecoratedEvent.t()]
  def construct(events) do
    events |> Enum.map(fn e -> construct_one(e) end)
  end

  @spec construct(InternalApi.Audit.Event.t()) :: __MODULE__.DecoratedEvent.t()
  def construct_one(event) do
    metadata = Poison.decode!(event.metadata)

    struct!(__MODULE__.DecoratedEvent,
      description: event.description,
      resource: Resource.key(event.resource),
      operation: Operation.key(event.operation),
      user_id: event.user_id,
      username: event.username,
      resource_id: event.resource_id,
      resource_name: event.resource_name,
      ip_address: event.ip_address,
      timestamp: event.timestamp.seconds,
      medium: Medium.key(event.medium),

      # initialy setting it to false, later the preloader can change it
      has_project: false,
      project_id: Map.get(metadata, "project_id", nil),

      # initialy setting it to false, later the preloader can change it
      has_workflow: false,
      workflow_id: Map.get(metadata, "workflow_id", nil),

      # initialy setting it to false, later the preloader can change it
      has_workflow: false,
      pipeline_id: Map.get(metadata, "pipeline_id", nil),

      # initialy setting it to false, later the preloader can change it
      has_job: false,
      job_id: Map.get(metadata, "job_id", nil),

      # inject agent data if the event is related to a self-hosted agent
      agent: decorate_agent(event, metadata)
    )
  end

  def sort(events) do
    events |> Enum.sort(fn e1, e2 -> e1.timestamp > e2.timestamp end)
  end

  def preload_referenced_items(events), do: Front.Audit.EventsDecorator.Preloader.preload(events)

  def decorate_agent(event, metadata) do
    if event.resource == Resource.value(:SelfHostedAgent) and metadata["agent_type_name"] != nil do
      %{
        agent_type_name: metadata["agent_type_name"],
        ip_address: metadata["ip_address"] || "N/A",
        hostname: metadata["hostname"] || "N/A",
        os: metadata["os"] || "N/A",
        version: metadata["version"] || "N/A",
        architecture: metadata["architecture"] || "N/A"
      }
    else
      %{}
    end
  end
end
