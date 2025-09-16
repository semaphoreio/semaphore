defmodule Front.Models.Scheduler do
  use Ecto.Schema

  alias InternalApi.PeriodicScheduler.{
    DeleteRequest,
    DeleteResponse,
    DescribeRequest,
    DescribeResponse,
    HistoryRequest,
    HistoryResponse,
    LatestTriggersRequest,
    LatestTriggersResponse,
    ListRequest,
    ListResponse,
    PauseRequest,
    PauseResponse,
    PeriodicService.Stub,
    PersistRequest,
    PersistResponse,
    RunNowRequest,
    RunNowResponse,
    UnpauseRequest,
    UnpauseResponse
  }

  alias InternalApi.Status, as: Status
  require Logger

  @required_fields [:name, :reference, :pipeline_file, :recurring]
  @default_page_args [page: 1, page_size: 10, page_query: ""]
  embedded_schema do
    field(:name, :string)
    field(:description, :string)
    field(:updated_at, :string)
    field(:project_id, :string)
    field(:recurring, :boolean)
    field(:reference, :string)
    field(:reference_type, :string, virtual: true)
    field(:reference_name, :string, virtual: true)
    field(:branch, :string, virtual: true)
    field(:at, :string)
    field(:parameters, :map)
    field(:pipeline_file, :string)
    field(:next, :string)
    field(:created_at, :string)
    field(:updated_by, :string)
    field(:activity_toggled_by, :string)
    field(:activity_toggled_at, :string)
    field(:inactive, :boolean)
    field(:blocked, :boolean)

    field(:latest_status, :string)
    field(:latest_scheduled_at, :string)
    field(:latest_triggered_at, :string)
    field(:latest_workflow_id, :string)
    field(:manually_triggered_by, :string)
    embeds_one(:latest_trigger, Trigger)
  end

  defmodule IndexPage do
    use TypedStruct
    alias Front.Models.Scheduler

    typedstruct do
      field(:entries, [Scheduler.t()])
      field(:number, :integer)
      field(:size, :integer)
      field(:total_entries, :integer)
      field(:total_pages, :integer)
    end

    def construct(schedulers, response) do
      %__MODULE__{
        entries: schedulers,
        number: response.page_number,
        size: response.page_size,
        total_entries: response.total_entries,
        total_pages: response.total_pages
      }
    end
  end

  defmodule HistoryPage do
    use TypedStruct
    alias Front.Models.Scheduler.Trigger

    typedstruct do
      field(:triggers, [Trigger.t()])
      field(:cursor_before, :integer)
      field(:cursor_after, :integer)
    end

    def construct(response) do
      %__MODULE__{
        triggers: Enum.into(response.triggers, [], &Trigger.construct/1),
        cursor_before: if(response.cursor_before > 0, do: response.cursor_before, else: nil),
        cursor_after: if(response.cursor_after > 0, do: response.cursor_after, else: nil)
      }
    end

    def preload(page = %__MODULE__{}) do
      page
      |> preload_workflows()
      |> preload_triggerers()
    end

    defp preload_workflows(page = %__MODULE__{}) do
      workflows =
        page.triggers
        |> Enum.map(& &1.workflow_id)
        |> Enum.uniq()
        |> Front.Models.Workflow.find_many()
        |> Front.Decorators.Workflow.decorate_many()
        |> Map.new(&{&1.id, &1})

      triggers =
        page.triggers
        |> Enum.into([], fn trigger ->
          workflow = Map.get(workflows, trigger.workflow_id)
          Trigger.preload_workflow(trigger, workflow)
        end)

      %__MODULE__{page | triggers: triggers}
    end

    defp preload_triggerers(page = %__MODULE__{}) do
      triggerers =
        page.triggers
        |> Enum.map(& &1.triggered_by)
        |> Enum.uniq()
        |> Front.Models.User.find_many()
        |> Map.new(&{&1.id, &1})

      triggers =
        page.triggers
        |> Enum.into([], fn trigger ->
          triggerer = Map.get(triggerers, trigger.triggered_by)
          Trigger.preload_triggerer(trigger, triggerer)
        end)

      %__MODULE__{page | triggers: triggers}
    end
  end

  defmodule Trigger do
    use TypedStruct

    typedstruct do
      field(:reference, :string)
      field(:reference_type, :string)
      field(:reference_name, :string)
      field(:branch, :string)
      field(:pipeline_file, :string)
      field(:workflow_id, :string)
      field(:status, :string)
      field(:scheduled_at, :utc_datetime)
      field(:triggered_at, :utc_datetime)
      field(:triggered_by, :string)
      field(:parameter_values, :map)

      field(:workflow, Front.Decorators.Workflow.t())
      field(:triggerer, Front.Models.User.t())
      field(:triggerer_name, :string)
      field(:triggerer_avatar_url, :string)
    end

    def construct(trigger) do
      {reference_type, reference_name} =
        Front.Models.Scheduler.parse_git_reference(trigger.reference)

      %__MODULE__{
        reference: trigger.reference,
        reference_type: reference_type,
        reference_name: reference_name,
        branch: reference_name,
        pipeline_file: trigger.pipeline_file,
        workflow_id: trigger.scheduled_workflow_id,
        status: trigger.scheduling_status,
        scheduled_at: trigger.scheduled_at.seconds,
        triggered_at: trigger.triggered_at.seconds,
        triggered_by: trigger.run_now_requester_id,
        parameter_values: Enum.into(trigger.parameter_values, %{}, &{&1.name, &1.value})
      }
    end

    def preload_workflow(trigger = %__MODULE__{}, workflow) do
      %__MODULE__{trigger | workflow: workflow}
    end

    def preload_triggerer(trigger = %__MODULE__{}, nil) do
      avatar_url = "#{FrontWeb.SharedHelpers.assets_path()}/images/profile-bot.svg"

      %__MODULE__{
        trigger
        | triggerer_name: "scheduler",
          triggerer_avatar_url: avatar_url
      }
    end

    def preload_triggerer(trigger = %__MODULE__{}, triggerer) do
      %__MODULE__{
        trigger
        | triggerer_name: triggerer.name,
          triggerer_avatar_url: triggerer.avatar_url
      }
    end
  end

  def api_endpoint do
    Application.fetch_env!(:front, :periodic_scheduler_grpc_endpoint)
  end

  def list(id, page_args \\ [], metadata \\ nil) do
    page_args = Keyword.merge(@default_page_args, page_args)
    {page, page_size, query} = {page_args[:page], page_args[:page_size], page_args[:query]}
    request = ListRequest.new(project_id: id, page: page, page_size: page_size, query: query)

    with {:ok, channel} <- GRPC.Stub.connect(api_endpoint()),
         {:ok, response = %ListResponse{status: %Status{code: 0}}} <-
           Stub.list(channel, request, options(metadata)),
         {:ok, periodics} <- add_triggers_info(response.periodics, channel, metadata) do
      {:ok, periodics |> construct() |> IndexPage.construct(response)}
    else
      {:ok, response} ->
        Watchman.increment("scheduler.list.failed")
        Logger.error("List schedulers failed: project #{id}, #{inspect(response.status)}")

        {:error, :grpc_req_failed}

      {:error, :grpc_req_failed} ->
        {:error, :grpc_req_failed}

      {:error, message} ->
        Watchman.increment("scheduler.list.failed")
        Logger.error("List schedulers failed: project #{id}, #{inspect(message)}")

        {:error, :grpc_req_failed}
    end
  end

  defp add_triggers_info([], _channel, _metadata), do: {:ok, []}

  defp add_triggers_info(periodics, channel, metadata) do
    with ids <- Enum.map(periodics, fn elem -> elem.id end),
         request <- LatestTriggersRequest.new(periodic_ids: ids),
         {:ok, response = %LatestTriggersResponse{status: %Status{code: 0}}} <-
           Stub.latest_triggers(channel, request, options(metadata)) do
      workflow_ids = Enum.into(response.triggers, [], & &1.scheduled_workflow_id)
      user_ids = Enum.into(response.triggers, [], & &1.run_now_requester_id)

      workflows =
        workflow_ids
        |> Front.Models.Workflow.find_many()
        |> Front.Decorators.Workflow.decorate_many()

      triggerers = Front.Models.User.find_many(user_ids)

      {:ok, combine_data(periodics, response.triggers, workflows, triggerers)}
    else
      {:ok, response} ->
        Watchman.increment("scheduler.latest_triggers.failed")
        Logger.error("Getting latest scheduler triggers failed: #{inspect(response.status)}")

        {:error, :grpc_req_failed}

      {:error, message} ->
        Watchman.increment("scheduler.latest_triggers.failed")
        Logger.error("Getting latest scheduler triggers failed: #{inspect(message)}")

        {:error, :grpc_req_failed}
    end
  end

  def pause(id, user_id, metadata \\ nil) do
    with {:ok, channel} <- GRPC.Stub.connect(api_endpoint()),
         request <- PauseRequest.new(id: id, requester: user_id),
         {:ok, _response = %PauseResponse{status: %Status{code: 0, message: msg}}} <-
           Stub.pause(channel, request, options(metadata)) do
      {:ok, msg}
    else
      {:ok, response} ->
        Watchman.increment("scheduler.pause.failed")
        Logger.error("Pause scheduler failed: #{id}, #{inspect(response.status)}")

        {:error, :grpc_req_failed}

      {:error, message} ->
        Watchman.increment("scheduler.pause.failed")
        Logger.error("Pause scheduler failed: #{id}, #{inspect(message)}")

        {:error, :grpc_req_failed}
    end
  end

  def unpause(id, user_id, metadata \\ nil) do
    with {:ok, channel} <- GRPC.Stub.connect(api_endpoint()),
         request <- UnpauseRequest.new(id: id, requester: user_id),
         {:ok, _response = %UnpauseResponse{status: %Status{code: 0, message: msg}}} <-
           Stub.unpause(channel, request, options(metadata)) do
      {:ok, msg}
    else
      {:ok, response} ->
        Watchman.increment("scheduler.unpause.failed")
        Logger.error("Unpause scheduler failed: #{id}, #{inspect(response.status)}")

        {:error, :grpc_req_failed}

      {:error, message} ->
        Watchman.increment("scheduler.unpause.failed")
        Logger.error("Unpause scheduler failed: #{id}, #{inspect(message)}")

        {:error, :grpc_req_failed}
    end
  end

  def run_now(id, user_id, just_run_params \\ %{}, metadata \\ nil) do
    run_now_params =
      just_run_params
      |> Map.merge(%{id: id, requester: user_id})
      |> Map.put(:reference, build_reference(just_run_params))
      |> Map.delete(:reference_type)
      |> Map.delete(:reference_name)

    with {:ok, channel} <- GRPC.Stub.connect(api_endpoint()),
         request <- Util.Proto.deep_new!(RunNowRequest, run_now_params),
         {:ok, response = %RunNowResponse{status: %Status{code: 0}}} <-
           Stub.run_now(channel, request, options(metadata)),
         triggers <- response.triggers ++ [empty_trigger()] do
      {:ok, construct({response.periodic, Enum.at(triggers, 0)})}
    else
      # Matches on RESOURCE_EXHAUSTED status code
      {:ok, response = %RunNowResponse{status: %Status{code: 8, message: msg}}} ->
        Watchman.increment("scheduler.run_now.failed")
        Logger.error("Scheduler run_now failed: #{id}, #{inspect(response.status)}")

        {:error, {:resource_exhausted, msg}}

      {:ok, response} ->
        Watchman.increment("scheduler.run_now.failed")
        Logger.error("Scheduler run_now failed: #{id}, #{inspect(response.status)}")

        {:error, :grpc_req_failed}

      {:error, message} ->
        Watchman.increment("scheduler.run_now.failed")
        Logger.error("Scheduler run_now failed: #{id}, #{inspect(message)}")

        {:error, :grpc_req_failed}
    end
  end

  def find(id, metadata \\ nil) do
    with {:ok, channel} <- GRPC.Stub.connect(api_endpoint()),
         request <- DescribeRequest.new(id: id),
         {:ok, response = %DescribeResponse{status: %Status{code: 0}}} <-
           Stub.describe(channel, request, options(metadata)),
         triggers <- response.triggers ++ [empty_trigger()] do
      {:ok, construct({response.periodic, Enum.at(triggers, 0)})}
    else
      {:ok, response} ->
        Watchman.increment("scheduler.describe.failed")
        Logger.error("Describe scheduler failed: #{id}, #{inspect(response.status)}")

        {:error, :grpc_req_failed}

      {:error, message} ->
        Watchman.increment("scheduler.describe.failed")
        Logger.error("Describe scheduler failed: #{id}, #{inspect(message)}")

        {:error, :grpc_req_failed}
    end
  end

  def history(id, params \\ [], metadata \\ nil) do
    request =
      Util.Proto.deep_new!(HistoryRequest, %{
        periodic_id: id,
        cursor_type: Keyword.get(params, :direction, :FIRST),
        cursor_value: Keyword.get(params, :timestamp, 0),
        filters: Keyword.get(params, :filters, %{})
      })

    with {:ok, channel} <- GRPC.Stub.connect(api_endpoint()),
         {:ok, response = %HistoryResponse{status: %Status{code: 0}}} <-
           Stub.history(channel, request, options(metadata)) do
      {:ok, HistoryPage.construct(response)}
    else
      {:ok, response} ->
        Watchman.increment("scheduler.history.failed")
        Logger.error("History scheduler failed: #{id}, #{inspect(response.status)}")

        {:error, :grpc_req_failed}

      {:error, message} ->
        Watchman.increment("scheduler.history.failed")
        Logger.error("History scheduler failed: #{id}, #{inspect(message)}")

        {:error, :grpc_req_failed}
    end
  end

  def latest_trigger(id, metadata \\ nil) do
    request = LatestTriggersRequest.new(periodic_ids: [id])

    with {:ok, channel} <- GRPC.Stub.connect(api_endpoint()),
         {:ok, response = %LatestTriggersResponse{status: %Status{code: 0}}} <-
           Stub.latest_triggers(channel, request, options(metadata)) do
      case response.triggers do
        [trigger] ->
          workflow =
            trigger.scheduled_workflow_id
            |> Front.Models.Workflow.find()
            |> Front.Decorators.Workflow.decorate_one()

          user = Front.Models.User.find(trigger.run_now_requester_id)

          Trigger.construct(trigger)
          |> Trigger.preload_workflow(workflow)
          |> Trigger.preload_triggerer(user)

        [] ->
          nil
      end
    else
      _ -> nil
    end
  end

  def persist(form_data, context_data, metadata \\ nil) do
    alias Front.Form.RequiredParams, as: RP

    action = if context_data[:id], do: "Updating", else: "Creating"
    changeset = RP.create_changeset(form_data, @required_fields, %__MODULE__{})
    all_data = Map.merge(form_data, context_data)
    scheduler_id = context_data[:id] || ""

    with true <- changeset.valid?,
         {:ok, channel} <- GRPC.Stub.connect(api_endpoint()),
         {:ok, request} <- Util.Proto.deep_new(PersistRequest, all_data),
         {:ok, %PersistResponse{status: %Status{code: 0}, periodic: periodic}} <-
           Stub.persist(channel, request, options(metadata)) do
      {:ok, periodic.id}
    else
      false ->
        {:error, changeset}

      {:ok, response = %PersistResponse{status: %Status{code: _c, message: msg}}} ->
        Watchman.increment("scheduler.persist.failed")
        Logger.error("#{action} scheduler failed: #{scheduler_id}, #{inspect(response.status)}")

        {:error, parse_error_response_message(msg)}

      {:error, message} ->
        Watchman.increment("scheduler.persist.failed")
        Logger.error("#{action} scheduler failed: #{scheduler_id}, #{inspect(message)}")

        {:error, :grpc_req_failed}
    end
  end

  def destroy(id, user_id, metadata \\ nil) do
    with {:ok, channel} <- GRPC.Stub.connect(api_endpoint()),
         request <- DeleteRequest.new(id: id, requester: user_id),
         {:ok, _response = %DeleteResponse{status: %Status{code: 0}}} <-
           Stub.delete(channel, request, options(metadata)) do
      {:ok, nil}
    else
      {:ok, response} ->
        Watchman.increment("scheduler.delete.failed")
        Logger.error("Delete scheduler failed: #{id}, #{inspect(response.status)}")

        {:error, :grpc_req_failed}

      {:error, message} ->
        Watchman.increment("scheduler.delete.failed")
        Logger.error("Delete scheduler failed: #{id}, #{inspect(message)}")

        {:error, :grpc_req_failed}
    end
  end

  def map_expression(expression) do
    case Crontab.CronExpression.Parser.parse(expression) do
      {:ok, value} ->
        expression =
          Crontab.CronExpression.Composer.compose(value)
          |> String.split(" ")
          |> Enum.take(5)
          |> Enum.join(" ")

        {:ok, expression}

      {:error, message} ->
        {:error, message}
    end
  end

  defp combine_data(periodics, triggers, workflows, triggerers) do
    workflows_by_id = Map.new(workflows, &{&1.id, &1})
    triggerers_by_id = Map.new(triggerers, &{&1.id, &1})

    periodics
    |> Enum.map(fn periodic ->
      trigger =
        Enum.find(triggers, empty_trigger(), fn tr ->
          periodic.id == tr.periodic_id
        end)

      workflow = trigger && Map.get(workflows_by_id, trigger.scheduled_workflow_id)
      triggerer = trigger && Map.get(triggerers_by_id, trigger.run_now_requester_id)

      {periodic, trigger, workflow, triggerer}
    end)
  end

  defp empty_trigger do
    %{
      reference: "",
      pipeline_file: "",
      scheduling_status: "",
      scheduled_at: %{seconds: 0},
      triggered_at: %{seconds: 0},
      scheduled_workflow_id: "",
      run_now_requester_id: "",
      parameter_values: []
    }
  end

  defp construct(periodics) when is_list(periodics) do
    Enum.map(periodics, fn x -> construct(x) end)
  end

  defp construct({raw_scheduler, latest_trigger}) do
    {reference_type, reference_name} = parse_git_reference(raw_scheduler.reference)

    %__MODULE__{
      id: raw_scheduler.id,
      name: raw_scheduler.name,
      description: raw_scheduler.description,
      updated_at: Front.Utils.decorate_relative(raw_scheduler.updated_at.seconds),
      project_id: raw_scheduler.project_id,
      recurring: raw_scheduler.recurring,
      next: "not-added-yet",
      reference: raw_scheduler.reference,
      reference_type: reference_type,
      reference_name: reference_name,
      branch: reference_name,
      at: raw_scheduler.at,
      parameters: construct_parameters(raw_scheduler.parameters),
      pipeline_file: raw_scheduler.pipeline_file,
      created_at:
        raw_scheduler.inserted_at &&
          Front.Utils.decorate_relative(raw_scheduler.inserted_at.seconds),
      updated_by: raw_scheduler.requester_id,
      activity_toggled_by: raw_scheduler.pause_toggled_by,
      activity_toggled_at:
        raw_scheduler.pause_toggled_at &&
          Front.Utils.decorate_relative(raw_scheduler.pause_toggled_at.seconds),
      inactive: raw_scheduler.paused,
      blocked: raw_scheduler.suspended,
      latest_status: latest_trigger.scheduling_status,
      latest_scheduled_at: Front.Utils.decorate_date(latest_trigger.scheduled_at.seconds),
      latest_triggered_at: Front.Utils.decorate_date(latest_trigger.triggered_at.seconds),
      latest_workflow_id: latest_trigger.scheduled_workflow_id,
      manually_triggered_by: latest_trigger.run_now_requester_id,
      latest_trigger: Trigger.construct(latest_trigger)
    }
  end

  defp construct({raw_scheduler, latest_trigger, latest_workflow, latest_triggerer}) do
    latest_trigger_with_preloads =
      unless latest_trigger == empty_trigger() do
        latest_trigger
        |> Trigger.construct()
        |> Trigger.preload_workflow(latest_workflow)
        |> Trigger.preload_triggerer(latest_triggerer)
      end

    construct({raw_scheduler, latest_trigger})
    |> Map.put(:latest_trigger, latest_trigger_with_preloads)
  end

  defp construct_parameters(parameters) do
    Enum.into(parameters, [], &Map.take(&1, ~w(name required description default_value options)a))
  end

  defp options(metadata) do
    [timeout: 30_000, metadata: metadata]
  end

  defp build_reference(params) do
    reference_type = Map.get(params, :reference_type, "branch")
    reference_name = Map.get(params, :reference_name) || Map.get(params, :reference, "")

    # Format as proper Git reference
    case String.downcase(to_string(reference_type)) do
      "tag" ->
        "refs/tags/#{String.trim(reference_name)}"

      "pr" ->
        "refs/pull/#{String.trim(reference_name)}/head"

      "pull_request" ->
        "refs/pull/#{String.trim(reference_name)}/head"

      _ ->
        # Default to branch
        "refs/heads/#{String.trim(reference_name)}"
    end
  end

  defp parse_error_response_message(msg) do
    cond do
      msg =~ "parameters" ->
        %{errors: %{parameters: msg}}

      msg =~ "name" ->
        %{errors: %{name: String.replace(msg, "Periodic with name", "Scheduler")}}

      msg =~ "reference" ->
        %{errors: %{reference: msg}}

      msg =~ "Invalid cron expression in 'at' field" ->
        %{
          errors: %{
            at:
              String.replace(
                msg,
                "Invalid cron expression in 'at' field:",
                "Invalid cron expression:"
              )
          }
        }

      true ->
        %{errors: %{other: msg}}
    end
  end

  def parse_git_reference(nil), do: {"branch", ""}
  def parse_git_reference(""), do: {"branch", ""}

  def parse_git_reference(reference) when is_binary(reference) do
    cond do
      String.starts_with?(reference, "refs/heads/") ->
        {"branch", String.replace_prefix(reference, "refs/heads/", "")}

      String.starts_with?(reference, "refs/tags/") ->
        {"tag", String.replace_prefix(reference, "refs/tags/", "")}

      String.starts_with?(reference, "refs/pull/") ->
        pr_number =
          reference
          |> String.replace_prefix("refs/pull/", "")
          |> String.replace_suffix("/head", "")

        {"pr", "PR ##{pr_number}"}

      String.contains?(reference, "/") ->
        # If it looks like a full reference but doesn't match known patterns, treat as branch
        parts = String.split(reference, "/")
        {"branch", List.last(parts)}

      true ->
        # Plain name, assume it's a branch
        {"branch", reference}
    end
  end
end
