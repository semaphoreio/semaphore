defmodule FrontWeb.SchedulersController do
  require Logger
  use FrontWeb, :controller

  alias Front.{Async, Audit}
  alias Front.Models.{Scheduler, User}
  alias FrontWeb.Plugs.{FetchPermissions, Header, PageAccess, PutProjectAssigns}

  plug(FetchPermissions, [scope: "org"] when action == :expression)
  plug(PageAccess, [permissions: "organization.view"] when action == :expression)

  plug(PutProjectAssigns when action != :expression)
  plug(FetchPermissions, [scope: "project"] when action != :expression)
  plug(PageAccess, [permissions: "project.view"] when action != :expression)
  plug(PageAccess, [permissions: "project.scheduler.view"] when action in [:history, :latest])
  plug(PageAccess, [permissions: "project.scheduler.manage"] when action == :destroy)

  plug(Header when action in [:index, :edit, :new, :show, :create, :update, :form_just_run])

  plug(:put_layout, :project)

  def expression(conn, params) do
    case Scheduler.map_expression(String.trim(params["expression"])) do
      {:ok, expression} ->
        json(conn, %{expression: expression})

      {:error, message} ->
        json(conn, %{error: message})
    end
  end

  def latest(conn, _params = %{"id" => scheduler_id}) do
    Watchman.benchmark("schedulers.latest.duration", fn ->
      case find_scheduler(scheduler_id, conn.assigns.project.id) do
        {:ok, _scheduler} ->
          maybe_latest_trigger = Async.run(fn -> Scheduler.latest_trigger(scheduler_id) end)
          {:ok, latest_trigger} = Async.await(maybe_latest_trigger)

          conn
          |> put_layout(false)
          |> render("tasks/last_run.html",
            project: conn.assigns.project,
            scheduler_id: scheduler_id,
            trigger: latest_trigger,
            permissions: conn.assigns.permissions
          )

        _ ->
          render_404(conn)
      end
    end)
  end

  def history(conn, params = %{"id" => scheduler_id}) do
    Watchman.benchmark("schedulers.history.duration", fn ->
      case find_scheduler(scheduler_id, conn.assigns.project.id) do
        {:ok, _scheduler} ->
          page_args = parse_history_page_args(conn.assigns, params)
          maybe_history = Async.run(fetch_history(scheduler_id, page_args))

          {:ok, history} = Async.await(maybe_history)
          {:ok, history_page} = Async.await(Async.run(preload_history(history)))

          conn
          |> put_layout(false)
          |> render("history/page.html",
            page: history_page,
            pollman: pollman_history(conn, scheduler_id, page_args)
          )

        _ ->
          render_404(conn)
      end
    end)
  end

  def index(conn, params) do
    Watchman.benchmark("schedulers.index.duration", fn ->
      project = conn.assigns.project
      page_args = parse_index_page_args(params)
      fetch_index_page = Async.run(fn -> Scheduler.list(project.id, page_args) end)
      {:ok, {:ok, index_page}} = Async.await(fetch_index_page)

      {:ok, schedulers} = user_ids_to_names(index_page.entries)
      index_page = %{index_page | entries: schedulers}

      assigns =
        %{
          project: project,
          js: "tasks",
          page: index_page,
          title: "Settings・#{project.name}",
          query: page_args[:query],
          permissions: conn.assigns.permissions
        }
        |> put_layout_assigns(conn, project)
        |> Front.Breadcrumbs.Project.construct(conn, :scheduler)

      render(conn, "index.html", assigns)
    end)
  end

  def show(conn, params = %{"id" => scheduler_id}) do
    Watchman.benchmark("schedulers.show.duration", fn ->
      case find_scheduler(scheduler_id, conn.assigns.project.id) do
        {:ok, scheduler} ->
          page_args = parse_history_page_args(conn.assigns, params)
          maybe_history = Async.run(fetch_history(scheduler_id, page_args))

          with {:ok, history} <- Async.await(maybe_history),
               {:ok, history_page} <- Async.await(Async.run(preload_history(history))),
               {:ok, [scheduler]} <- user_ids_to_names([scheduler]) do
            assigns =
              %{
                project: conn.assigns.project,
                js: "tasks",
                scheduler: scheduler,
                history_page: history_page,
                pollman: pollman_history(conn, scheduler_id, page_args),
                page_args: page_args,
                title: "Task History・#{scheduler.name}",
                permissions: conn.assigns.permissions
              }
              |> put_layout_assigns(conn, conn.assigns.project)
              |> Front.Breadcrumbs.Project.construct(conn, :scheduler)

            render(conn, "show.html", assigns)
          end

        _ ->
          render_404(conn)
      end
    end)
  end

  def new(conn, _params) do
    Watchman.benchmark("schedulers.new.duration", fn ->
      project = conn.assigns.project
      scheduler = compose_default_form_values(project.name)

      assigns =
        %{
          scheduler: scheduler,
          project: project,
          permissions: conn.assigns.permissions,
          validation_errors: nil,
          js: "tasks",
          title: "Settings・#{project.name}"
        }
        |> put_layout_assigns(conn, project)
        |> Front.Breadcrumbs.Project.construct(conn, :scheduler)

      render(
        conn,
        "new.html",
        assigns
      )
    end)
  end

  def create(conn, params) do
    Watchman.benchmark("schedulers.create.duration", fn ->
      scheduler_input = parse_form_input(params)
      context = context_data(conn.assigns)
      project = conn.assigns.project

      audit =
        conn
        |> Audit.new(:PeriodicScheduler, :Added)
        |> Audit.add(description: "Added a periodic scheduler")
        |> Audit.add(resource_name: scheduler_input.name)
        |> Audit.metadata(
          reference_name: scheduler_input.reference_name,
          reference_type: scheduler_input.reference_type,
          project_name: context.project_name,
          pipeline_file: scheduler_input.pipeline_file
        )
        |> Audit.log()

      with true <- conn.assigns.permissions["project.scheduler.manage"],
           {:ok, scheduler_id} <- Scheduler.persist(scheduler_input, context) do
        audit
        |> Audit.add(:resource_id, scheduler_id)
        |> Audit.log()

        conn
        |> put_flash(:notice, "Schedule created.")
        |> redirect(to: schedulers_path(conn, :index, project.name))
      else
        false ->
          assigns =
            %{
              validation_errors: nil,
              scheduler: scheduler_input,
              project: project,
              permissions: conn.assigns.permissions,
              js: "tasks",
              title: "Settings・#{project.name}"
            }
            |> put_layout_assigns(conn, project)
            |> Front.Breadcrumbs.Project.construct(conn, :scheduler)

          conn
          |> put_flash(:alert, compose_alert_message(:blocked_by_guard, "create"))
          |> put_status(422)
          |> render(
            "new.html",
            assigns
          )

        {:error, m = :grpc_req_failed} ->
          assigns =
            %{
              validation_errors: nil,
              scheduler: scheduler_input,
              project: project,
              permissions: conn.assigns.permissions,
              js: "tasks",
              title: "Settings・#{project.name}"
            }
            |> put_layout_assigns(conn, project)
            |> Front.Breadcrumbs.Project.construct(conn, :scheduler)

          conn
          |> put_flash(:alert, compose_alert_message(m, "create"))
          |> put_status(422)
          |> render(
            "new.html",
            assigns
          )

        {:error, validation_errors} ->
          assigns =
            %{
              validation_errors: validation_errors,
              scheduler: scheduler_input,
              project: project,
              permissions: conn.assigns.permissions,
              js: "tasks",
              title: "Settings・#{project.name}"
            }
            |> put_layout_assigns(conn, project)
            |> Front.Breadcrumbs.Project.construct(conn, :scheduler)

          conn
          |> put_flash(:alert, compose_alert_message(validation_errors.errors, "create"))
          |> put_status(422)
          |> render(
            "new.html",
            assigns
          )

        _error ->
          conn
          |> render_404
      end
    end)
  end

  def edit(conn, params) do
    Watchman.benchmark("schedulers.edit.duration", fn ->
      project = conn.assigns.project
      id = params["id"]

      case find_scheduler(id, project.id) do
        {:ok, scheduler} ->
          scheduler =
            if empty?(scheduler.at),
              do: %{scheduler | at: "0 0 * * *"},
              else: scheduler

          assigns =
            %{
              scheduler: scheduler,
              validation_errors: nil,
              permissions: conn.assigns.permissions,
              project: project,
              js: "tasks",
              title: "Settings・#{project.name}"
            }
            |> put_layout_assigns(conn, project)
            |> Front.Breadcrumbs.Project.construct(conn, :scheduler)

          render(
            conn,
            "edit.html",
            assigns
          )

        _ ->
          conn
          |> render_404
      end
    end)
  end

  def update(conn, params) do
    Watchman.benchmark("schedulers.update.duration", fn ->
      scheduler_input = parse_form_input(params)
      context = context_data(conn.assigns, params["id"])
      project = conn.assigns.project
      scheduler_id = params["id"]

      with true <- conn.assigns.permissions["project.scheduler.manage"],
           {:ok, _scheduler} <- find_scheduler(scheduler_id, project.id),
           {:ok, scheduler_id} <-
             Scheduler.persist(scheduler_input, context) do
        conn
        |> Audit.new(:PeriodicScheduler, :Modified)
        |> Audit.add(description: "Modified a periodic scheduler")
        |> Audit.add(resource_name: scheduler_input.name)
        |> Audit.add(resource_id: scheduler_id)
        |> Audit.metadata(
          reference_name: scheduler_input.reference_name,
          reference_type: scheduler_input.reference_type,
          project_name: context.project_name,
          pipeline_file: scheduler_input.pipeline_file
        )
        |> Audit.log()

        conn
        |> put_flash(:notice, "Schedule updated.")
        |> redirect(to: schedulers_path(conn, :index, project.name))
      else
        false ->
          assigns =
            %{
              validation_errors: nil,
              scheduler: scheduler_input |> Map.put(:id, scheduler_id),
              project: project,
              permissions: conn.assigns.permissions,
              js: "tasks",
              title: "Settings・#{project.name}"
            }
            |> put_layout_assigns(conn, project)
            |> Front.Breadcrumbs.Project.construct(conn, :scheduler)

          conn
          |> put_flash(:alert, compose_alert_message(:blocked_by_guard, "update"))
          |> put_status(422)
          |> render(
            "edit.html",
            assigns
          )

        {:error, :not_found} ->
          conn |> render_404

        {:error, m = :grpc_req_failed} ->
          assigns =
            %{
              validation_errors: nil,
              scheduler: scheduler_input |> Map.put(:id, scheduler_id),
              project: project,
              permissions: conn.assigns.permissions,
              js: "tasks",
              title: "Settings・#{project.name}"
            }
            |> put_layout_assigns(conn, project)
            |> Front.Breadcrumbs.Project.construct(conn, :scheduler)

          conn
          |> put_flash(:alert, compose_alert_message(m, "update"))
          |> put_status(422)
          |> render(
            "edit.html",
            assigns
          )

        {:error, validation_errors} ->
          assigns =
            %{
              validation_errors: validation_errors,
              scheduler: scheduler_input |> Map.put(:id, scheduler_id),
              project: project,
              permissions: conn.assigns.permissions,
              js: "tasks",
              title: "Settings・#{project.name}"
            }
            |> put_layout_assigns(conn, project)
            |> Front.Breadcrumbs.Project.construct(conn, :scheduler)

          conn
          |> put_flash(:alert, compose_alert_message(validation_errors.errors, "update"))
          |> put_status(422)
          |> render(
            "edit.html",
            assigns
          )

        _error ->
          conn
          |> render_404
      end
    end)
  end

  def destroy(conn, params) do
    Watchman.benchmark("schedulers.destroy.duration", fn ->
      user_id = conn.assigns.user_id
      project = conn.assigns.project
      scheduler_id = params["id"]

      conn
      |> Audit.new(:PeriodicScheduler, :Removed)
      |> Audit.add(description: "Removed a periodic scheduler")
      |> Audit.add(resource_id: scheduler_id)
      |> Audit.metadata(project_id: project.id)
      |> Audit.log()

      with {:ok, _scheduler} <- find_scheduler(scheduler_id, project.id),
           true <- conn.assigns.permissions["project.scheduler.manage"],
           {:ok, nil} <- Scheduler.destroy(scheduler_id, user_id) do
        conn
        |> put_flash(:notice, "Scheduler deleted.")
        |> redirect(to: schedulers_path(conn, :index, project.name))
      else
        {:error, :not_found} ->
          conn |> render_404

        {:error, _response} ->
          conn
          |> put_flash(:alert, "Failed to delete the scheduler.")
          |> redirect(to: schedulers_path(conn, :index, project.name))

        _error ->
          conn
          |> render_404
      end
    end)
  end

  def activate(conn, params) do
    Watchman.benchmark("schedulers.activate.duration", fn ->
      user_id = conn.assigns.user_id
      project = conn.assigns.project
      scheduler_id = params["id"]

      conn
      |> Audit.new(:PeriodicScheduler, :Started)
      |> Audit.add(description: "Activated a periodic scheduler")
      |> Audit.add(resource_id: scheduler_id)
      |> Audit.metadata(project_id: project.id)
      |> Audit.log()

      with true <- conn.assigns.permissions["project.scheduler.manage"],
           {:ok, _scheduler} <- find_scheduler(scheduler_id, project.id),
           {:ok, _msg} <- Scheduler.unpause(scheduler_id, user_id) do
        conn
        |> put_flash(:notice, "Scheduler activated.")
        |> redirect(to: schedulers_path(conn, :index, project.name))
      else
        false ->
          conn
          |> put_flash(:alert, compose_alert_message(:blocked_by_guard, "activate"))
          |> redirect(to: schedulers_path(conn, :index, project.name))

        {:error, :not_found} ->
          conn |> render_404

        {:error, _response} ->
          conn
          |> put_flash(:alert, "Failed to activate the scheduler.")
          |> redirect(to: schedulers_path(conn, :index, project.name))

        _error ->
          conn
          |> render_404
      end
    end)
  end

  def deactivate(conn, params) do
    Watchman.benchmark("schedulers.deactivate.duration", fn ->
      user_id = conn.assigns.user_id
      project = conn.assigns.project
      scheduler_id = params["id"]

      conn
      |> Audit.new(:PeriodicScheduler, :Stopped)
      |> Audit.add(description: "Deactivated a periodic scheduler")
      |> Audit.add(resource_id: scheduler_id)
      |> Audit.metadata(project_id: project.id)
      |> Audit.log()

      with true <- conn.assigns.permissions["project.scheduler.manage"],
           {:ok, _scheduler} <- find_scheduler(scheduler_id, project.id),
           {:ok, _msg} <- Scheduler.pause(scheduler_id, user_id) do
        conn
        |> put_flash(:notice, "Scheduler deactivated.")
        |> redirect(to: schedulers_path(conn, :index, project.name))
      else
        false ->
          conn
          |> put_flash(:alert, compose_alert_message(:blocked_by_guard, "deactivate"))
          |> redirect(to: schedulers_path(conn, :index, project.name))

        {:error, :not_found} ->
          conn |> render_404

        {:error, _response} ->
          conn
          |> put_flash(:alert, "Failed to deactivate the scheduler.")
          |> redirect(to: schedulers_path(conn, :index, project.name))

        _error ->
          conn
          |> render_404
      end
    end)
  end

  def form_just_run(conn, params) do
    Watchman.benchmark("schedulers.form_run.duration", fn ->
      case find_scheduler(params["id"], conn.assigns.project.id) do
        {:ok, scheduler} ->
          just_run_params = parse_just_run_form_params(params, scheduler)
          render_just_run(conn, params, scheduler, just_run_params)

        _ ->
          render_404(conn)
      end
    end)
  end

  def trigger_just_run(conn, params) do
    Watchman.benchmark("schedulers.trigger_run.duration", fn ->
      user_id = conn.assigns.user_id
      project = conn.assigns.project
      scheduler_id = params["id"]

      with true <- conn.assigns.permissions["project.scheduler.run_manually"],
           {:ok, scheduler} <- find_scheduler(scheduler_id, project.id),
           just_run_params <- parse_just_run_trigger_params(params, scheduler),
           {:ok, %{parameters: run_now_params}} <-
             validate_run_now_parameters(scheduler, just_run_params),
           {:ok, scheduler} <- Scheduler.run_now(scheduler_id, user_id, run_now_params),
           {:ok, [_scheduler]} <- user_ids_to_names([scheduler]) do
        conn
        |> Audit.new(:PeriodicScheduler, :Promoted)
        |> Audit.add(description: "Workflow manually triggered based on periodic scheduler")
        |> Audit.add(resource_id: scheduler_id)
        |> Audit.metadata(project_id: project.id)
        |> Audit.log()

        conn
        |> put_flash(:notice, "Workflow started successfully.")
        |> redirect(to: schedulers_path(conn, :show, project.name, scheduler_id))
      else
        false ->
          conn
          |> put_flash(:alert, "You do not have sufficient rights to start tasks manually.")
          |> redirect(to: schedulers_path(conn, :index, project.name))

        {:error, :not_found} ->
          conn |> render_404

        {:error, {:validation, %{scheduler: scheduler, parameters: just_run_params}}} ->
          conn
          |> put_flash(:alert, "Unable to start workflow, please provide correct data.")
          |> render_just_run(params, scheduler, just_run_params)

        {:error, {:resource_exhausted, msg}} ->
          Logger.error("Starting JustRun workflow failed: #{inspect({:resource_exhausted, msg})}")

          conn
          |> put_flash(:alert, "Unable to start workflow, pipeline queue limit reached.")
          |> redirect(to: schedulers_path(conn, :form_just_run, project.name, scheduler_id))

        error ->
          Logger.error("Starting JustRun workflow failed: #{inspect(error)}")

          conn
          |> put_flash(:alert, "Starting workflow failed.")
          |> redirect(to: schedulers_path(conn, :form_just_run, project.name, scheduler_id))
      end
    end)
  end

  defp render_just_run(conn, _params, scheduler, just_run_params) do
    project = conn.assigns.project

    assigns =
      %{
        project: project,
        permissions: conn.assigns.permissions,
        validation_errors: nil,
        js: "tasks",
        scheduler: scheduler,
        form_params: just_run_params,
        title: "Run・#{project.name}"
      }
      |> put_layout_assigns(conn, project)
      |> Front.Breadcrumbs.Project.construct(conn, :scheduler)

    render(conn, "run.html", assigns)
  end

  defp find_scheduler(scheduler_id, project_id) do
    case Scheduler.find(scheduler_id) do
      {:ok, %{project_id: ^project_id} = scheduler} -> {:ok, scheduler}
      _ -> {:error, :not_found}
    end
  end

  defp fetch_history(periodic_id, page_args),
    do: fn ->
      case Scheduler.history(periodic_id, page_args) do
        {:ok, result} -> result
        {:error, error} -> raise "Failed to fetch history: #{inspect(error)}"
      end
    end

  defp preload_history(history_page),
    do: fn -> Scheduler.HistoryPage.preload(history_page) end

  defp user_ids_to_names(schedulers) do
    user_ids = extract_users(schedulers)
    users = User.find_many(user_ids)
    users_map = Enum.reduce(users, %{}, fn user, map -> Map.put(map, user.id, user) end)
    schedulers = replace_ids_with_names(schedulers, users_map)

    {:ok, schedulers}
  end

  defp extract_users(schedulers) do
    schedulers
    |> Enum.reduce([], fn scheduler, acc ->
      acc = if scheduler.updated_by != "", do: acc ++ [scheduler.updated_by], else: acc

      acc =
        if scheduler.activity_toggled_by != "",
          do: acc ++ [scheduler.activity_toggled_by],
          else: acc

      if scheduler.manually_triggered_by != "",
        do: acc ++ [scheduler.manually_triggered_by],
        else: acc
    end)
    |> Enum.uniq()
  end

  defp replace_ids_with_names(schedulers, users_map) do
    schedulers
    |> Enum.reduce([], fn scheduler, acc ->
      scheduler = replace_id_with_name(scheduler, :updated_by, users_map)
      scheduler = replace_id_with_name(scheduler, :activity_toggled_by, users_map)
      scheduler = replace_id_with_name(scheduler, :manually_triggered_by, users_map)
      acc ++ [scheduler]
    end)
  end

  defp replace_id_with_name(scheduler, field, users_map) do
    id = Map.get(scheduler, field)

    if id != "" do
      user = Map.get(users_map, id, %{})
      username = Map.get(user, :name, Application.get_env(:front, :default_user_name))
      Map.put(scheduler, field, username)
    else
      scheduler
    end
  end

  defp put_layout_assigns(assigns, conn, project) do
    user_id = conn.assigns.user_id
    org_id = conn.assigns.organization_id

    is_project_starred? =
      Front.Tracing.track(conn.assigns.trace_id, "check_if_project_is_starred", fn ->
        Watchman.benchmark("project_page_check_star", fn ->
          Front.Models.User.has_favorite(user_id, org_id, project.id)
        end)
      end)

    assigns
    |> Map.put(:starred?, is_project_starred?)
    |> Map.put(:layout, {FrontWeb.LayoutView, "project.html"})
  end

  defp validate_run_now_parameters(scheduler, parameters) do
    errors =
      []
      |> validate_run_now_field(parameters, :reference_name)
      |> validate_run_now_field(parameters, :pipeline_file)
      |> validate_run_now_parameter_values(parameters)

    if Enum.empty?(errors) do
      parameter_values = Enum.into(parameters.parameters, [], &%{name: &1.name, value: &1.value})

      {:ok,
       %{
         errors: [],
         scheduler: scheduler,
         parameters: %{
           reference_type: parameters.reference_type,
           reference_name: parameters.reference_name,
           pipeline_file: parameters.pipeline_file,
           parameter_values: parameter_values
         }
       }}
    else
      {:error,
       {:validation,
        %{
          errors: errors,
          scheduler: scheduler,
          parameters: parameters
        }}}
    end
  end

  defp validate_run_now_field(errors, parameters, field_name) do
    validation_error =
      if empty?(parameters[field_name]),
        do: %{field: field_name, name: "", message: "This field is required"}

    Enum.reject([validation_error | errors], &is_nil/1)
  end

  defp validate_run_now_parameter_values(errors, parameters) do
    validation_errors =
      Enum.map(parameters.parameters, fn pv ->
        if empty?(pv.value) and pv.required,
          do: %{field: :parameters, name: pv.name, message: "This parameter is required"}
      end)

    validation_errors |> Enum.reject(&is_nil/1) |> Enum.concat(errors)
  end

  defp empty?(nil), do: true
  defp empty?(""), do: true
  defp empty?([]), do: true
  defp empty?(_), do: false

  defp context_data(assigns) do
    %{
      organization_id: assigns.organization_id,
      requester_id: assigns.user_id,
      project_id: assigns.project.id,
      project_name: assigns.project.name
    }
  end

  defp context_data(assigns, scheduler_id) do
    Map.put(context_data(assigns), :id, scheduler_id)
  end

  defp parse_form_input(params) do
    recurring? = params["recurring"] != "false"
    reference_type = params["reference_type"] || "branch"
    reference_name = String.trim(params["reference_name"] || "")

    %{
      at: get_at_value(params, recurring?),
      reference_type: reference_type,
      reference_name: reference_name,
      name: params["name"],
      description: params["description"] || "",
      pipeline_file: params["pipeline_file"],
      recurring: recurring?,
      parameters: parse_form_parameters(params["parameters"] || %{})
    }
  end

  defp get_at_value(params, true), do: String.trim(params["at"] || "")
  defp get_at_value(_params, false), do: ""

  defp parse_form_parameters(parameters) do
    parameters |> Map.values() |> Enum.map(&parse_form_input_parameter/1)
  end

  defp parse_form_input_parameter(parameter) do
    %{
      name: parameter["name"],
      description: parameter["description"] || "",
      required: parameter["required"] == "on",
      default_value: parameter["default_value"] || "",
      options: parse_form_input_parameter_options(parameter["options"])
    }
  end

  defp parse_just_run_form_params(params, scheduler) do
    reference_type = params["reference_type"] || "branch"

    reference_name =
      String.trim(params["reference_name"] || params["branch"] || scheduler.reference_name || "")

    pipeline_file = params["pipeline_file"] || scheduler.pipeline_file
    parameter_values = params["parameters"] || %{}

    parameters = merge_form_values_with_default_values(scheduler, parameter_values)

    %{
      reference_type: reference_type,
      reference_name: reference_name,
      pipeline_file: pipeline_file,
      parameters: parameters
    }
  end

  defp parse_just_run_trigger_params(params, scheduler) do
    reference_type = params["reference_type"] || "branch"

    reference_name = String.trim(params["reference_name"] || scheduler.reference_name || "")

    pipeline_file = params["pipeline_file"] || scheduler.pipeline_file

    parameter_values =
      (params["parameters"] || %{}) |> Map.values() |> Enum.into(%{}, &{&1["name"], &1["value"]})

    parameters = merge_form_values_with_default_values(scheduler, parameter_values)

    %{
      reference_type: reference_type,
      reference_name: reference_name,
      pipeline_file: pipeline_file,
      parameters: parameters
    }
  end

  defp merge_form_values_with_default_values(scheduler, values) do
    Enum.into(scheduler.parameters, [], fn parameter ->
      value = Map.get(values, parameter.name) || parameter.default_value

      options =
        if not Enum.empty?(parameter.options) &&
             not empty?(value) &&
             not Enum.member?(parameter.options, value),
           do: [value | parameter.options],
           else: parameter.options

      Map.merge(parameter, %{value: value, options: options})
    end)
  end

  defp parse_form_input_parameter_options(text) do
    text
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(String.length(&1) < 1))
  end

  defp parse_index_page_args(params) do
    page =
      case Integer.parse(params["page"] || "") do
        {value, _} -> value
        :error -> 1
      end

    [page: if(page < 1, do: 1, else: page), query: params["search"] || ""]
  end

  defp parse_history_page_args(assigns, params) do
    direction = params |> Map.get("direction", "") |> parse_history_direction()
    timestamp = params |> Map.get("timestamp", "") |> parse_history_timestamp()

    filter_keys = ~w(branch_name pipeline_file triggered_by)a
    filters = Enum.into(filter_keys, %{}, &{&1, parse_history_filter(params, &1)})

    [direction: direction, timestamp: timestamp, filters: filters, requester_id: assigns.user_id]
  end

  defp parse_history_direction("BEFORE"), do: :BEFORE
  defp parse_history_direction("AFTER"), do: :AFTER
  defp parse_history_direction(_direction), do: :FIRST

  defp parse_history_timestamp(timestamp) do
    now = DateTime.utc_now() |> DateTime.to_unix(:microsecond)

    case Integer.parse(timestamp) do
      {value, _} -> abs(value)
      :error -> now
    end
  end

  defp parse_history_filter(params, key) do
    key_name_with_underscores = to_string(key)
    key_name_with_dashes = String.replace(to_string(key), "_", "-")

    Map.get(params, key_name_with_underscores) ||
      Map.get(params, key_name_with_dashes) || ""
  end

  defp pollman_history(conn, scheduler_id, page_args) do
    pollman_href = schedulers_path(conn, :history, conn.assigns.project.name, scheduler_id)

    pollman_filters = [
      "branch-name": page_args[:filters][:branch_name],
      "pipeline-file": page_args[:filters][:pipeline_file],
      "triggered-by": page_args[:filters][:triggered_by]
    ]

    params =
      page_args
      |> Keyword.merge(pollman_filters)
      |> Keyword.drop([:filters, :requester_id])

    %{href: pollman_href, state: "poll", param: params}
  end

  defp compose_alert_message(message, action) do
    case message do
      :blocked_by_guard ->
        "You are not allowed to #{action} the scheduler. Please reach out to support if you think this is a mistake."

      :grpc_req_failed ->
        # there was a grpc communication issues

        "Failed to #{action} the scheduler. Please try again later."

      %{other: m} ->
        # Periodic Scheduler returned an unexpected validation error
        # This error isn't communicated within the form

        "Failed: #{m}"

      _ ->
        # Periodic Scheduler returned expected validation error
        # this error is communicated within the form
        Logger.error("Failed to #{action} the scheduler: #{inspect(message)}")

        "Failed to #{action} the scheduler."
    end
  end

  defp compose_default_form_values(project_name) do
    %{
      at: "0 0 * * *",
      reference_type: "branch",
      reference_name: "master",
      name: "",
      description: "",
      recurring: true,
      pipeline_file: ".semaphore/semaphore.yml",
      project_name: project_name,
      parameters: []
    }
  end

  defp render_404(conn) do
    conn
    |> put_status(:not_found)
    |> put_layout(false)
    |> put_view(FrontWeb.ErrorView)
    |> render("404.html")
  end
end
