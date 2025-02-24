# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule FrontWeb.DeploymentsController do
  use FrontWeb, :controller
  require Logger

  alias Front.{Async, Audit}
  alias Front.Breadcrumbs.Project, as: Breadcrumbs
  alias Front.Models.DeploymentDetails, as: Details
  alias Front.Models.Deployments
  alias Front.Models.DeploymentTarget, as: Target
  alias FrontWeb.Plugs.{FetchPermissions, Header, PageAccess, PutProjectAssigns}

  @view ~w(index show new edit)a
  @modify ~w(cordon create update delete)a

  plug(PutProjectAssigns)
  plug(FetchPermissions, scope: "project")
  plug(PageAccess, [permissions: "project.view"] when action in @view)
  plug(PageAccess, [permissions: "project.deployment_targets.manage"] when action in @modify)

  # plug(FrontWeb.Plugs.ProjectAuthorization)
  plug(Header)
  plug(:authorize_feature)

  @watchman_prefix "deployments.endpoint"
  @grpc_not_found GRPC.Status.not_found()

  def index(conn, _params) do
    Watchman.benchmark(watchman_name(:index, :duration), fn ->
      maybe_targets = Async.run(fetch_targets_with_details(conn.assigns))
      {:ok, targets} = Async.await(maybe_targets)

      render_page(conn, "index.html", targets)
    end)
  end

  def show(conn, params = %{"id" => target_id}) do
    Watchman.benchmark(watchman_name(:show, :duration), fn ->
      page_args = parse_history_page_args(conn.assigns, params)

      maybe_target = Async.run(fetch_target(target_id, conn.assigns))

      with {:ok, target} <- Async.await(maybe_target),
           maybe_history <- Async.run(fetch_history(target_id, page_args)),
           {:ok, history} <- Async.await(maybe_history) do
        maybe_target_details = Async.run(fetch_target_details(target, history, conn.assigns))
        {:ok, target_details} = Async.await(maybe_target_details)

        render_page(conn, "show.html", target_details, %{page_args: page_args})
      else
        {:exit, {%GRPC.RPCError{status: @grpc_not_found}, _stacktrace}} ->
          Logger.warn("[DT] Target not found: target_id=#{target_id}")
          render_404(conn)
      end
    end)
  end

  def new(conn, _params) do
    Watchman.benchmark(watchman_name(:new, :duration), fn ->
      resources = load_resources(conn.assigns)
      render_page(conn, "new.html", Target.changeset(), resources)
    end)
  end

  def edit(conn, _params = %{"id" => target_id}) do
    Watchman.benchmark(watchman_name(:edit, :duration), fn ->
      maybe_secret_data = Async.run(fetch_secret_data(target_id, conn.assigns))
      maybe_target = Async.run(fetch_target(target_id, conn.assigns))
      resources = load_resources(conn.assigns)

      with {:ok, secret_data} <- Async.await(maybe_secret_data),
           {:ok, target} <- Async.await(maybe_target) do
        model = Target.from_api(target, secret_data)
        changeset = Target.changeset(model, %{})
        render_page(conn, "edit.html", changeset, resources)
      else
        {:exit, {%GRPC.RPCError{status: @grpc_not_found}, _stacktrace}} ->
          Logger.warn("[DT] Target not found: target_id=#{target_id}")
          render_404(conn)
      end
    end)
  end

  def create(conn, _params = %{"target" => model_params}) do
    Watchman.benchmark(watchman_name(:create, :duration), fn ->
      model_params = preprocess_params(conn, model_params)
      changeset = Target.changeset(model_params)
      resources = load_resources(conn.assigns)

      case Deployments.create(model_params, extra_args(conn)) do
        {:ok, target} ->
          audit_log(conn, :create, target.id)

          conn
          |> put_flash(:notice, "Success: deployment target created")
          |> redirect(to: deployments_path(conn, :index, conn.assigns.project.name))

        {:error, %Ecto.Changeset{} = changeset} ->
          Logger.debug(fn -> "[DT] Invalid data: #{inspect(changeset)}" end)

          conn
          |> put_flash(:alert, "Failure: provided invalid data")
          |> render_page("new.html", changeset, resources)

        {:error, reason} ->
          Logger.error("[DT] Unable to update deployment target: reason=#{inspect(reason)}")

          conn
          |> put_flash(:alert, "Failure: unable to create target")
          |> render_page("new.html", changeset, resources)
      end
    end)
  end

  def update(conn, _params = %{"id" => target_id, "target" => model_params}) do
    Watchman.benchmark(watchman_name(:update, :duration), fn ->
      model_params = preprocess_params(conn, model_params)
      project_name = conn.assigns.project.name

      maybe_secret_data = Async.run(fetch_secret_data(target_id, conn.assigns))
      maybe_target = Async.run(fetch_target(target_id, conn.assigns))
      resources = load_resources(conn.assigns)

      with {:ok, secret_data} <- Async.await(maybe_secret_data),
           {:ok, target} <- Async.await(maybe_target) do
        model = Target.from_api(target, secret_data)
        changeset = Target.changeset(model, model_params)

        case Deployments.update(model, model_params, secret_data, extra_args(conn)) do
          {:ok, target} ->
            audit_log(conn, :update, target.id)

            conn
            |> put_flash(:notice, "Success: deployment target updated")
            |> redirect(to: deployments_path(conn, :index, project_name))

          {:error, %Ecto.Changeset{} = changeset} ->
            Logger.debug(fn -> "[DT] Invalid data: #{inspect(changeset)}" end)

            conn
            |> put_flash(:alert, "Failure: provided invalid data")
            |> render_page("edit.html", changeset, resources)

          {:error, %GRPC.RPCError{status: @grpc_not_found}} ->
            Logger.warn("[DT] Target not found: target_id=#{target_id}")

            conn
            |> put_flash(:alert, "Failure: deployment target was not found")
            |> redirect(to: deployments_path(conn, :index, project_name))

          {:error, reason} ->
            Logger.error("[DT] Unable to update deployment target: reason=#{inspect(reason)}")

            conn
            |> put_flash(:alert, "Failure: unable to update target")
            |> render_page("edit.html", changeset, resources)
        end
      else
        {:exit, {%GRPC.RPCError{status: @grpc_not_found}, _stacktrace}} ->
          render_404(conn)
      end
    end)
  end

  def cordon(conn, _params = %{"id" => target_id, "state" => "on"}),
    do: do_cordon(conn, target_id, :on)

  def cordon(conn, _params = %{"id" => target_id, "state" => "off"}),
    do: do_cordon(conn, target_id, :off)

  def cordon(conn, _params),
    do: render_404(conn)

  defp do_cordon(conn, target_id, state) do
    Watchman.benchmark(watchman_name(:cordon, :duration), fn ->
      project_name = conn.assigns.project.name
      flash_verb = if state == :on, do: "block", else: "unblock"
      maybe_target = Async.run(fetch_target(target_id, conn.assigns))

      with {:ok, _target} <- Async.await(maybe_target),
           {:ok, ^target_id} <- Deployments.switch_cordon(target_id, state) do
        audit_log(conn, {:cordon, state}, target_id)

        conn
        |> put_flash(:notice, "Success: deployment target has been #{flash_verb}ed")
        |> redirect(to: deployments_path(conn, :index, project_name))
      else
        {:exit, {%GRPC.RPCError{status: @grpc_not_found}, _stacktrace}} ->
          Logger.warn("[DT] Target not found: target_id=#{target_id}")
          render_404(conn)

        {:error, %GRPC.RPCError{status: @grpc_not_found}} ->
          Logger.warn("[DT] Target not found: target_id=#{target_id}")

          conn
          |> put_flash(:alert, "Failure: deployment target was not found")
          |> redirect(to: deployments_path(conn, :index, project_name))

        {:error, reason} ->
          Logger.error("[DT] Unable to #{flash_verb} DT: reason=#{inspect(reason)}")

          conn
          |> put_flash(:alert, "Failure: unable to #{flash_verb} Deployment Target")
          |> redirect(to: deployments_path(conn, :index, project_name))
      end
    end)
  end

  def delete(conn, _params = %{"id" => target_id}) do
    Watchman.benchmark(watchman_name(:delete, :duration), fn ->
      project_name = conn.assigns.project.name
      maybe_target = Async.run(fetch_target(target_id, conn.assigns))

      with {:ok, _target} <- Async.await(maybe_target),
           {:ok, target_id} <- Deployments.delete(target_id, extra_args(conn)) do
        audit_log(conn, :delete, target_id)

        conn
        |> put_flash(:notice, "Success: deployment target deleted")
        |> redirect(to: deployments_path(conn, :index, project_name))
      else
        {:exit, {%GRPC.RPCError{status: @grpc_not_found}, _stacktrace}} ->
          Logger.warn("[DT] Target not found: target_id=#{target_id}")
          render_404(conn)

        {:error, reason} ->
          Logger.error("[DT] Unable to delete deployment target: reason=#{inspect(reason)}")

          conn
          |> put_flash(:alert, "Failure: unable to delete target")
          |> redirect(to: deployments_path(conn, :index, project_name))
      end
    end)
  end

  defp load_resources(assigns) do
    org_id = assigns.organization_id
    project_id = assigns.project.id

    maybe_members = Async.run(fetch_members(org_id, project_id))
    maybe_roles = Async.run(fetch_roles(org_id))

    {:ok, members} = Async.await(maybe_members)
    {:ok, roles} = Async.await(maybe_roles)

    roles = Enum.into(roles, [], &%{id: &1.id, name: &1.name})
    %{members: members, roles: roles}
  end

  defp extra_args(conn) do
    %{
      organization_id: conn.assigns.organization_id,
      project_id: conn.assigns.project.id,
      requester_id: conn.assigns.user_id
    }
  end

  defp fetch_targets_with_details(assigns),
    do: fn ->
      case Deployments.fetch_targets(assigns.project.id, assigns.user_id) do
        {:ok, targets} -> Details.load(targets)
        {:error, error} -> raise error
      end
    end

  defp fetch_roles(org_id),
    do: fn ->
      case Front.RBAC.RoleManagement.list_possible_roles(org_id, "project_scope") do
        {:ok, roles} -> roles
        {:error, error} -> raise error
      end
    end

  @pg_no 0
  @pg_size 1000
  defp fetch_members(org_id, project_id, query \\ ""),
    do: fn ->
      case Front.RBAC.Members.list_project_members(org_id, project_id,
             username: query,
             page_no: @pg_no,
             page_size: @pg_size
           ) do
        {:ok, {members, _total_pages}} -> members
        {:error, error} -> raise error
      end
    end

  defp fetch_target(target_id, assigns),
    do: fn ->
      project_id = assigns.project.id

      case Deployments.fetch_target(target_id) do
        {:ok, %{project_id: ^project_id} = target} -> target
        {:ok, _target} -> raise %GRPC.RPCError{status: @grpc_not_found, message: "not found"}
        {:error, error} -> raise error
      end
    end

  defp fetch_history(target_id, page_args),
    do: fn ->
      case Deployments.fetch_history(target_id, page_args) do
        {:ok, response} -> Details.HistoryPage.construct(response)
        {:error, error} -> raise error
      end
    end

  defp fetch_target_details(target, history, _assings),
    do: fn -> Details.load(target, history) end

  defp fetch_secret_data(target_id, assigns),
    do: fn ->
      meta_args = [org_id: assigns.organization_id, user_id: assigns.user_id]

      case Deployments.fetch_secret_data(target_id, meta_args) do
        {:ok, secret_data} -> secret_data
        {:error, error} -> raise error
      end
    end

  defp render_page(conn, template, target, resources \\ %{})

  defp render_page(conn, "index.html", targets, resources) do
    render_project_page(conn, "index.html", resources,
      title: "Deployment targets・#{conn.assigns.project.name}",
      js: :deployments_index,
      targets: targets
    )
  end

  defp render_page(conn, "show.html", target, resources) do
    render_project_page(conn, "show.html", resources,
      title: "Deployment target・#{target.name}",
      js: :deployments_show,
      target: target
    )
  end

  defp render_page(conn, "new.html", changeset, resources) do
    render_project_page(conn, "new.html", resources,
      title: "Create deployment target・#{conn.assigns.project.name}",
      js: :deployments_new,
      changeset: changeset
    )
  end

  defp render_page(conn, "edit.html", changeset, resources) do
    render_project_page(conn, "edit.html", resources,
      title: "Edit deployment target・#{conn.assigns.project.name}",
      js: :deployments_edit,
      changeset: changeset
    )
  end

  defp render_zero_page(conn) do
    conn
    |> render_project_page("zero_page.html", %{},
      title: "Deployment targets・#{conn.assigns.project.name}"
    )
    |> Plug.Conn.halt()
  end

  defp render_project_page(conn, template, resources, args) do
    default_args = %{
      organization: conn.assigns.layout_model.current_organization,
      project: conn.assigns.project,
      notice: get_flash(conn, :notice),
      alert: get_flash(conn, :alert),
      layout: {FrontWeb.LayoutView, "project.html"},
      starred?: is_starred?(conn),
      resources: resources
    }

    final_args =
      default_args
      |> Breadcrumbs.construct(conn, :deployments)
      |> Map.merge(Map.new(args))

    render(conn, template, final_args)
  end

  defp is_starred?(conn) do
    org_id = conn.assigns.organization_id
    user_id = conn.assigns.user_id
    project = conn.assigns.project

    Front.Tracing.track(conn.assigns.trace_id, "check_if_project_is_starred", fn ->
      Watchman.benchmark("project_page_check_star", fn ->
        Front.Models.User.has_favorite(user_id, org_id, project.id)
      end)
    end)
  end

  defp authorize_feature(conn, _opts) do
    case feature_state(conn) do
      :enabled -> conn
      :zero_state -> render_zero_page(conn)
      :hidden -> render_404(conn)
    end
  end

  defp feature_state(conn) do
    feature_type = :deployment_targets
    org_id = conn.assigns[:organization_id]

    cond do
      FeatureProvider.feature_enabled?(feature_type, param: org_id) -> :enabled
      FeatureProvider.feature_zero_state?(feature_type, param: org_id) -> :zero_state
      true -> :hidden
    end
  end

  defp parse_history_page_args(assigns, params) do
    direction = params |> Map.get("direction", "") |> parse_history_direction()
    timestamp = params |> Map.get("timestamp", "") |> parse_history_timestamp()

    filter_keys = ~w(git_ref_type git_ref_label triggered_by parameter1 parameter2 parameter3)a
    filters = Enum.into(filter_keys, %{}, &{&1, Map.get(params, to_string(&1), "")})

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

  def preprocess_params(conn, params) do
    params
    |> maybe_override_user_access(conn.assigns[:organization_id])
    |> maybe_put_empty(~w(env_vars files roles members branches tags))
    |> reject_empty_items("env_vars", ~w(name value md5))
    |> reject_empty_items("files", ~w(path content md5))
    |> reject_empty_items("branches", ~w(pattern))
    |> reject_empty_items("tags", ~w(pattern))
  end

  defp maybe_override_user_access(params, organization_id) do
    if FeatureProvider.feature_enabled?(:advanced_deployment_targets, param: organization_id),
      do: params,
      else: Map.put(params, "user_access", "any")
  end

  defp maybe_put_empty(params, collection_names)
       when is_map(params) and is_list(collection_names) do
    Enum.reduce(collection_names, params, &Map.put_new(&2, &1, []))
  end

  defp reject_empty_items(params, collection_name, fields) do
    Map.update(params, collection_name, [], &reject_empty_items(&1, fields))
  end

  defp reject_empty_items(collection, fields) when is_map(collection),
    do: collection |> Map.values() |> Enum.reject(&empty_item?(&1, fields))

  defp reject_empty_items(collection, fields) when is_list(collection),
    do: collection |> Enum.reject(&empty_item?(&1, fields))

  defp empty_item?(item, fields),
    do: Enum.all?(fields, &(item |> Map.get(&1, "") |> String.equivalent?("")))

  defp render_404(conn) do
    conn
    |> FrontWeb.PageController.status404(%{})
    |> Plug.Conn.halt()
  end

  def audit_log(conn, action, target_id) do
    conn
    |> Audit.new(:Project, :Modified)
    |> Audit.add(description: audit_desc(action))
    |> Audit.add(resource_id: conn.assigns.project.id)
    |> Audit.metadata(requester_id: conn.assigns.user_id)
    |> Audit.metadata(target_id: target_id)
    |> Audit.log()
  end

  defp audit_desc(:create), do: "Created deployment target"
  defp audit_desc(:update), do: "Updated deployment target"
  defp audit_desc(:delete), do: "Deleted deployment target"
  defp audit_desc({:cordon, :on}), do: "Cordoned deployment target"
  defp audit_desc({:cordon, :off}), do: "Decordoned deployment target"

  #
  # Watchman callbacks
  #
  defp watchman_name(method, metrics), do: "#{@watchman_prefix}.#{method}.#{metrics}"
end
