# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule FrontWeb.AuditController do
  require Logger
  use FrontWeb, :controller

  alias Front.Async
  alias Front.Models.AuditLog

  plug(:restrict_access)
  plug(:restrict_streaming_access when action not in [:index, :csv])
  plug(FrontWeb.Plugs.FetchPermissions, scope: "org")
  plug(FrontWeb.Plugs.PageAccess, permissions: "organization.view")

  plug(
    FrontWeb.Plugs.PageAccess,
    [permissions: "organization.audit_logs.manage"]
    when action in [:status, :create, :update, :delete, :setup]
  )

  plug(
    FrontWeb.Plugs.PageAccess,
    [permissions: "organization.audit_logs.view"]
    when action in [:show, :csv]
  )

  plug(FrontWeb.Plugs.Header when action in [:index, :show, :setup, :create, :update])

  @watchman_prefix "audit.endpoint"

  def index(conn, params) do
    Watchman.benchmark(watchman_name(:index, :duration), fn ->
      org_id = conn.assigns.organization_id

      page_token = params |> Map.get("page_token", "")
      direction = params |> Map.get("direction", "next")
      page_size = params |> Map.get("page_size", "30") |> Integer.parse() |> elem(0)

      fetch_org = Async.run(fn -> Front.Models.Organization.find(org_id) end)

      fetch_events =
        Async.run(fn ->
          Front.Audit.UI.list_events(org_id, page_token, direction, page_size)
        end)

      {:ok, org} = Async.await(fetch_org)
      {:ok, {events, next_page_token, previous_page_token}} = Async.await(fetch_events)

      pagination = %{
        next: next_page_token,
        previous: previous_page_token,
        page_size: page_size
      }

      Watchman.increment(watchman_name(:index, :success))

      conn
      |> render("index.html",
        conn: conn,
        permissions: conn.assigns.permissions,
        title: "Audit Logs・Semaphore",
        events: events,
        org: org,
        pagination: pagination,
        layout: {FrontWeb.LayoutView, "organization.html"}
      )
    end)
  end

  def show(conn, params) do
    Watchman.benchmark(watchman_name(:stream_log, :duration), fn ->
      organization_id = conn.assigns.organization_id
      user_id = conn.assigns.user_id

      page_token = params |> Map.get("page_token", "")
      direction = params |> Map.get("direction", "next")
      page_size = params |> Map.get("page_size", "10") |> Integer.parse() |> elem(0)

      maybe_stream_logs =
        Async.run(fetch_stream_logs(organization_id, page_token, direction, page_size))

      maybe_stream = Async.run(fetch_stream(organization_id))

      log_data = log_data_closure(organization_id, user_id, :show)

      with {:ok, logs} <- Async.await(maybe_stream_logs),
           {:ok, stream} <- Async.await(maybe_stream) do
        Watchman.increment(watchman_name(:stream_log, :success))

        if stream.stream != nil do
          render(conn, "streaming/index.html",
            stream: decorate_stream(stream),
            stream_log: logs,
            permissions: conn.assigns.permissions,
            layout: {FrontWeb.LayoutView, "organization.html"}
          )
        else
          redirect(conn, to: FrontWeb.Router.Helpers.audit_path(conn, :setup))
        end
      else
        {:error, reason} ->
          Logger.error(log_data.(reason))
          Watchman.increment(watchman_name(:stream_log, :failure))
          {:error, reason}
      end
    end)
  end

  def setup(conn, params) do
    Watchman.benchmark(watchman_name(:setup, :duration), fn ->
      organization_id = conn.assigns.organization_id
      user_id = conn.assigns.user_id

      provider =
        params
        |> Map.get("provider", "0")
        |> Integer.parse()
        |> elem(0)
        |> InternalApi.Audit.StreamProvider.key()

      maybe_stream = Async.run(fetch_stream(organization_id))

      log_data = log_data_closure(organization_id, user_id, :setup)

      Async.await(maybe_stream)
      |> case do
        {:ok, stream} ->
          Watchman.increment(watchman_name(:setup, :success))

          case Front.Models.AuditLog.get_changeset(stream.stream, provider) do
            {:new, changeset} ->
              render_page(conn, changeset, %{
                provider: provider,
                permissions: conn.assigns.permissions,
                action: audit_path(conn, :create)
              })

            {:matching_provider, changeset} ->
              render_page(conn, changeset, %{
                provider: provider,
                permissions: conn.assigns.permissions,
                action: audit_path(conn, :update)
              })

            {:already_exists, existing_provider, changeset} ->
              render_page(conn, changeset, %{
                provider: existing_provider,
                permissions: conn.assigns.permissions,
                action: audit_path(conn, :update),
                redirected: true
              })
          end

        {:error, reason} ->
          Logger.error(log_data.(reason))
          Watchman.increment(watchman_name(:setup, :failure))
          {:error, reason}
      end
    end)
  end

  def test_connection(conn, %{"s3" => s3_config}) do
    Watchman.benchmark(watchman_name(:test_connection, :duration), fn ->
      org_id = conn.assigns.organization_id
      user_id = conn.assigns.user_id

      changeset =
        Front.Models.AuditLog.S3.empty() |> Front.Models.AuditLog.S3.changeset(s3_config)

      maybe_secrets = Async.run(fetch_secrets(org_id, user_id))

      with {:ok, secrets} <- Async.await(maybe_secrets),
           {:ok, conn} <-
             validate_and_test(conn, changeset, %{
               permissions: conn.assigns.permissions,
               secrets: secrets,
               provider: :S3,
               action: audit_path(conn, :create)
             }) do
        Watchman.increment(watchman_name(:test_connection, :success))
        conn
      else
        _reason ->
          Watchman.increment(watchman_name(:test_connection, :failure))

          conn
          |> put_flash(:alert, "Failure: Unable to configure audit log streaming.")
          |> redirect(to: audit_path(conn, :setup))
      end
    end)
  end

  def status(conn, %{"action" => action}) do
    Watchman.benchmark(watchman_name(:status, :duration), fn ->
      org_id = conn.assigns.organization_id
      user_id = conn.assigns.user_id

      result =
        case action do
          "pause" ->
            Front.Models.AuditLog.set_state(org_id, user_id, :PAUSED)

          "active" ->
            Front.Models.AuditLog.set_state(org_id, user_id, :ACTIVE)
        end

      case result do
        {:ok, _} ->
          Watchman.increment(watchman_name(:status, :success))

          conn
          |> put_flash(:notice, "Success.")
          |> redirect(to: audit_path(conn, :show))

        {:error, _} ->
          Watchman.increment(watchman_name(:status, :failure))

          conn
          |> put_flash(:alert, "Error.")
          |> redirect(to: audit_path(conn, :show))
      end
    end)
  end

  def create(conn, %{"s3" => s3_config}) do
    Watchman.benchmark(watchman_name(:create, :duration), fn ->
      org_id = conn.assigns.organization_id
      user_id = conn.assigns.user_id

      changeset =
        Front.Models.AuditLog.S3.empty()
        |> Front.Models.AuditLog.S3.changeset(s3_config)

      maybe_secrets = Async.run(fetch_secrets(org_id, user_id))

      with {:ok, secrets} <- Async.await(maybe_secrets),
           {:ok, provider} <-
             Front.Models.AuditLog.provider(Map.get(s3_config, "provider", "S3")),
           {:ok, conn} <-
             validate_and_create(conn, changeset, %{
               permissions: conn.assigns.permissions,
               secrets: secrets,
               provider: provider,
               action: audit_path(conn, :create)
             }) do
        Watchman.increment(watchman_name(:create, :success))
        conn
      else
        {:error, %Plug.Conn{} = conn} ->
          Watchman.increment(watchman_name(:create, :failure))

          conn

        {:error, _reason} ->
          Watchman.increment(watchman_name(:create, :failure))

          conn
          |> put_flash(:alert, "Failure: Unable to configure audit log streaming.")
      end
    end)
  end

  def update(conn, %{"s3" => s3_config}) do
    Watchman.benchmark(watchman_name(:update, :duration), fn ->
      org_id = conn.assigns.organization_id
      user_id = conn.assigns.user_id

      changeset =
        Front.Models.AuditLog.S3.empty()
        |> Front.Models.AuditLog.S3.changeset(s3_config)

      maybe_secrets = Async.run(fetch_secrets(org_id, user_id))

      with {:ok, secrets} <- Async.await(maybe_secrets),
           {:ok, provider} <-
             Front.Models.AuditLog.provider(Map.get(s3_config, "provider", "S3")),
           {:ok, conn} <-
             validate_and_apply(conn, changeset, %{
               permissions: conn.assigns.permissions,
               secrets: secrets,
               provider: provider,
               action: audit_path(conn, :update)
             }) do
        Watchman.increment(watchman_name(:update, :success))
        conn
      else
        {:error, %Plug.Conn{} = conn} ->
          Watchman.increment(watchman_name(:update, :failure))

          conn

        {:error, _reason} ->
          Watchman.increment(watchman_name(:update, :failure))

          conn
          |> put_flash(:alert, "Failure: Unable to configure audit log streaming.")
      end
    end)
  end

  defp validate_and_apply(conn, changeset, params) do
    org_id = conn.assigns.organization_id
    user_id = conn.assigns.user_id
    log_data = log_data_closure(org_id, user_id, :validate_and_apply)

    with {:ok, model} <- Ecto.Changeset.apply_action(changeset, :insert),
         {:ok, _model} <- AuditLog.update(org_id, user_id, model) do
      {:ok,
       conn
       |> put_flash(:notice, "Saved audit log streaming settings.")
       |> redirect(to: audit_path(conn, :show))}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:ok,
         conn
         |> put_flash(:alert, "Failure: provided invalid data")
         |> render_page(changeset, params)}

      {:error, %GRPC.RPCError{status: _status, message: _message} = reason} ->
        Logger.error(log_data.(reason))

        {:error,
         conn
         |> put_flash(:alert, "Failure: provided invalid data")
         |> put_status(422)
         |> render_page(changeset, params)}
    end
  end

  defp validate_and_create(conn, changeset, params) do
    org_id = conn.assigns.organization_id
    user_id = conn.assigns.user_id
    log_data = log_data_closure(org_id, user_id, :validate_and_create)

    with {:ok, model} <- Ecto.Changeset.apply_action(changeset, :insert),
         {:ok, _model} <- AuditLog.create(org_id, user_id, model) do
      {:ok,
       conn
       |> put_flash(:notice, "Saved audit log streaming settings.")
       |> redirect(to: audit_path(conn, :show))}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:ok,
         conn
         |> put_flash(:alert, "Failure: provided invalid data")
         |> render_page(changeset, params)}

      {:error, %GRPC.RPCError{status: _status, message: _message} = reason} ->
        Logger.error(log_data.(reason))

        {:error,
         conn
         |> put_flash(:alert, "Failure: provided invalid data")
         |> put_status(422)
         |> render_page(changeset, params)}
    end
  end

  defp validate_and_test(conn, changeset, params) do
    org_id = conn.assigns.organization_id

    with {:ok, model} <- Ecto.Changeset.apply_action(changeset, :insert),
         {:ok, test_result} <- AuditLog.test_stream(org_id, model) do
      case test_result do
        %{success: true, message: msg} ->
          {:ok,
           conn
           |> put_flash(:notice, "Streaming works. " <> msg)
           |> render_page(changeset, params)}

        %{success: false, message: msg} ->
          {:ok,
           conn
           |> put_flash(:alert, "Streaming setup not working: " <> msg)
           |> render_page(changeset, params)}
      end
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:ok,
         conn
         |> put_flash(:alert, "Failure: provided invalid data")
         |> render_page(changeset, params)}

      {:error, %GRPC.RPCError{message: msg, status: 2}} ->
        {:ok, conn |> put_flash(:alert, "Failure: " <> msg) |> render_page(changeset, params)}
    end
  end

  def delete(conn, _params) do
    Watchman.benchmark(watchman_name(:delete, :duration), fn ->
      org_id = conn.assigns.organization_id
      result = AuditLog.destroy(org_id)

      case result do
        {:ok, _response} ->
          Watchman.increment(watchman_name(:delete, :success))

          conn
          |> put_flash(:notice, "Removed audit log streaming settings.")
          |> redirect(to: audit_path(conn, :index))

        {:error, %GRPC.RPCError{} = _reason} ->
          Watchman.increment(watchman_name(:delete, :failure))

          conn
          |> put_flash(:alert, "Failure: Unable to delete audit log streaming settings.")
          |> redirect(to: audit_path(conn, :show))
      end
    end)
  end

  def csv(conn, _params) do
    Watchman.benchmark("audit.csv.duration", fn ->
      data = Front.Audit.UI.csv(conn.assigns.organization_id)

      conn |> send_download({:binary, data}, filename: "audit.csv")
    end)
  end

  defp render_page(conn, changeset, params) do
    default_params = %{
      redirected: false
    }

    params = Map.merge(default_params, params)

    render(conn, "streaming/_form.html",
      permissions: params.permissions,
      changeset: changeset,
      provider: params.provider,
      redirected: params.redirected,
      action: params.action,
      js: :audit_logs,
      layout: {FrontWeb.LayoutView, "organization.html"}
    )
  end

  defp decorate_stream(%{stream: nil}), do: %{setup_exists: false, stream: nil, meta: nil}

  defp decorate_stream(stream),
    do: %{setup_exists: true, stream: stream.stream, meta: decorate_meta(stream.meta)}

  defp decorate_meta(raw_meta) do
    {:ok, names_meta} = user_ids_to_names(raw_meta)

    %{
      created_at: Front.Utils.decorate_relative(raw_meta.created_at.seconds),
      updated_at: Front.Utils.decorate_relative(raw_meta.updated_at.seconds),
      activity_toggled_at: Front.Utils.decorate_relative(raw_meta.activity_toggled_at.seconds),
      updated_by: names_meta.updated_by,
      activity_toggled_by: names_meta.activity_toggled_by
    }
  end

  defp user_ids_to_names(meta) do
    user_ids = extract_users(meta)
    users = Front.Models.User.find_many(user_ids)
    users_map = Enum.reduce(users, %{}, fn user, map -> Map.put(map, user.id, user) end)
    meta = replace_ids_with_names(meta, users_map)

    {:ok, meta}
  end

  defp extract_users(meta) do
    [meta.updated_by, meta.activity_toggled_by]
    |> Enum.filter(fn x -> x != "" end)
    |> Enum.uniq()
  end

  defp replace_ids_with_names(meta, users_map) do
    meta = replace_id_with_name(meta, :updated_by, users_map)
    replace_id_with_name(meta, :activity_toggled_by, users_map)
  end

  defp replace_id_with_name(meta, field, users_map) do
    id = Map.get(meta, field)

    if id != "" do
      user = Map.get(users_map, id)
      Map.put(meta, field, user.name)
    else
      meta
    end
  end

  defp fetch_secrets(organization_id, user_id),
    do: fn -> Front.Models.Secret.list(user_id, organization_id, "", :ORGANIZATION, true) end

  defp fetch_stream_logs(org_id, page_token, direction, page_size),
    do: fn ->
      Front.Audit.UI.list_stream_logs(org_id, page_token, direction, page_size)
    end

  defp fetch_stream(org_id),
    do: fn ->
      case Front.Models.AuditLog.describe(org_id) do
        {:ok, stream} ->
          # here model is API.Stream, not one of Front.Models.AuditLog
          # so we need to convert it to Front.Models.AuditLog based on provider
          # if model does not match provider, then we need to tell
          # client that he needs to delete old stream before creating new
          stream

        {:error, :not_found} ->
          %{stream: nil, meta: nil}

        {:error, error} ->
          raise error
      end
    end

  defp log_data_closure(organization_id, user_id, action) do
    fn reason ->
      formatter = &"#{elem(&1, 0)}=\"#{inspect(elem(&1, 1))}\""

      %{
        organization_id: organization_id,
        requester_id: user_id,
        action: action,
        reason: reason
      }
      |> Enum.map_join(" ", formatter)
    end
  end

  defp restrict_access(conn, _) do
    org_id = conn.assigns.organization_id

    if FeatureProvider.feature_enabled?(:audit_logs, param: org_id) do
      conn
    else
      render_404(conn)
    end
  end

  defp restrict_streaming_access(conn, _) do
    org_id = conn.assigns.organization_id

    if FeatureProvider.feature_enabled?(:audit_streaming, param: org_id) do
      conn
    else
      render_404(conn)
    end
  end

  defp render_404(conn) do
    conn
    |> put_status(:not_found)
    |> put_layout(false)
    |> put_view(FrontWeb.ErrorView)
    |> render("404.html")
    |> halt()
  end

  defp watchman_name(method, metrics), do: "#{@watchman_prefix}.#{method}.#{metrics}"
end
