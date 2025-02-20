defmodule FrontWeb.SelfHostedAgentController do
  use FrontWeb, :controller
  require Logger

  alias Front.Audit
  alias Front.SelfHostedAgents.AgentType

  plug(FrontWeb.Plugs.FetchPermissions, scope: "org")
  plug(FrontWeb.Plugs.PageAccess, permissions: "organization.view")

  plug(
    FrontWeb.Plugs.PageAccess,
    [permissions: "organization.self_hosted_agents.manage"]
    when action in [
           :reset_token,
           :confirm_delete,
           :confirm_disable,
           :confirm_disable_all,
           :confirm_reset_token,
           :disable_agent,
           :disable_all_agents,
           :delete,
           :create,
           :update
         ]
  )

  plug(
    FrontWeb.Plugs.Header
    when action in [
           :index,
           :show,
           :edit,
           :new,
           :create,
           :confirm_delete,
           :confirm_disable,
           :confirm_disable_all,
           :confirm_reset_token,
           :disable_agent,
           :disable_all_agents,
           :reset_token
         ]
  )

  plug(:put_layout, :organization)
  plug(:authorize_feature)

  def index(conn, _params) do
    {:ok, agent_types} = AgentType.list(org_id(conn))

    render(conn, "index.html",
      agent_types: agent_types,
      permissions: conn.assigns.permissions,
      title: "Self Hosted Agents・Semaphore"
    )
  end

  def new(conn, _params) do
    render(conn, "new.html",
      title: "New Self Hosted Agents・Semaphore",
      js: :self_hosted_agents_new,
      permissions: conn.assigns.permissions,
      agent_type_model: agent_type_model(nil),
      action: :new
    )
  end

  def edit(conn, _params = %{"id" => agent_type_name}) do
    {:ok, agent_type} = AgentType.find(org_id(conn), agent_type_name)

    model = agent_type_model(agent_type)

    Logger.info("Model: #{inspect(model)}")

    render(conn, "new.html",
      title: "New Self Hosted Agents・Semaphore",
      js: :self_hosted_agents_new,
      permissions: conn.assigns.permissions,
      agent_type_model: agent_type_model(agent_type),
      action: :edit
    )
  end

  defp agent_type_model(
         agent_type = %{
           agent_name_settings: %{assignment_origin: 1, release_after: release_after}
         }
       ) do
    %{
      name_suffix: String.slice(agent_type.name, 3..-1),
      agent_name_assignment_origin: :ASSIGNMENT_ORIGIN_AGENT,
      aws_account: "",
      aws_role_patterns: "",
      agent_name_release: release_after == 0,
      agent_name_release_after: release_after
    }
  end

  defp agent_type_model(
         agent_type = %{
           agent_name_settings: %{
             assignment_origin: 2,
             aws: aws,
             release_after: release_after
           }
         }
       ) do
    %{
      name_suffix: String.slice(agent_type.name, 3..-1),
      agent_name_assignment_origin: :ASSIGNMENT_ORIGIN_AWS_STS,
      aws_account: aws.account_id,
      aws_role_patterns: aws.role_name_patterns,
      agent_name_release: release_after == 0,
      agent_name_release_after: release_after
    }
  end

  defp agent_type_model(nil) do
    %{
      name_suffix: "",
      agent_name_assignment_origin: :ASSIGNMENT_ORIGIN_AGENT,
      aws_account: "",
      aws_role_patterns: "",
      agent_name_release: true,
      agent_name_release_after: 0
    }
  end

  def create(conn, params = %{"format" => "json"}) do
    create_agent_type(conn, params)
    |> case do
      {:ok, agent_type, token} ->
        conn
        |> json(%{
          agent_type: build_agent_type(agent_type),
          token: token
        })

      {:error, %GRPC.RPCError{status: 3, message: message}} ->
        conn
        |> put_status(422)
        |> json(%{
          message: "Error creating agent type: #{message}"
        })

      {:error, e} ->
        Logger.error("Unknown error creating agent type: #{inspect(e)}")

        conn
        |> put_status(422)
        |> json(%{
          message: "Error creating agent type: unknown error"
        })
    end
  end

  def create(conn, params) do
    create_agent_type(conn, params)
    |> case do
      {:ok, agent_type, token} ->
        name = params["name"]

        render(conn, "show.html",
          agent_type: agent_type,
          agents: [],
          first_page_url: first_page_url(name),
          next_page_url: next_page_url("", name),
          token: token,
          instructions: "installation",
          title: "#{name}・Self Hosted Agents・Semaphore",
          js: :self_hosted_agents_create
        )

      {:error, %GRPC.RPCError{status: 3, message: message}} ->
        conn
        |> put_flash(:alert, "Error creating agent type: #{message}")
        |> redirect(to: self_hosted_agent_path(conn, :new))

      {:error, e} ->
        Logger.error("Unknown error creating agent type: #{inspect(e)}")

        conn
        |> put_flash(:alert, "Error creating agent type: unknown error")
        |> redirect(to: self_hosted_agent_path(conn, :new))
    end
  end

  defp create_agent_type(conn, params) do
    name = params["name"]
    user_id = conn.assigns.user_id

    params =
      params["self_hosted_agent"] ||
        %{
          "agent_name_assignment_origin" => "ASSIGNMENT_ORIGIN_AGENT",
          "agent_name_release_after" => "0",
          "aws" => nil
        }

    AgentType.create(org_id(conn), name, user_id, params)
    |> case do
      {:ok, _agent_type, _token} = result ->
        conn
        |> Audit.new(:SelfHostedAgentType, :Added)
        |> Audit.add(description: "Added a self-hosted agent type")
        |> Audit.add(resource_name: name)
        |> Audit.log()

        result

      other ->
        other
    end
  end

  def update(conn, params = %{"id" => agent_type_name, "format" => "json"}) do
    update_agent_type(conn, agent_type_name, params)
    |> case do
      {:ok, agent_type} ->
        conn
        |> json(%{
          agent_type: build_agent_type(agent_type)
        })

      {:error, %GRPC.RPCError{status: 3, message: message}} ->
        conn
        |> put_status(422)
        |> json(%{
          message: "Error updating agent type: #{message}"
        })

      {:error, e} ->
        Logger.error("Unknown error updating agent type: #{inspect(e)}")

        conn
        |> put_status(422)
        |> json(%{
          message: "Error updating agent type: unknown error"
        })
    end
  end

  def update(conn, params = %{"id" => agent_type_name}) do
    update_agent_type(conn, agent_type_name, params)
    |> case do
      {:ok, _agent_type} ->
        redirect(conn, to: self_hosted_agent_path(conn, :show, agent_type_name))

      {:error, %GRPC.RPCError{status: 3, message: message}} ->
        conn
        |> put_flash(:alert, "Error updating agent type: #{message}")
        |> redirect(to: self_hosted_agent_edit_path(conn, :edit, agent_type_name))

      {:error, e} ->
        Logger.error("Unknown error updating agent type: #{inspect(e)}")

        conn
        |> put_flash(:alert, "Error creating agent type: unknown error")
        |> redirect(to: self_hosted_agent_edit_path(conn, :edit, agent_type_name))
    end
  end

  defp update_agent_type(conn, agent_type_name, params) do
    {:ok, _agent_type} = AgentType.find(org_id(conn), agent_type_name)
    user_id = conn.assigns.user_id
    params = params["self_hosted_agent"]

    AgentType.update(org_id(conn), agent_type_name, user_id, params)
    |> case do
      {:ok, _} = res ->
        conn
        |> Audit.new(:SelfHostedAgentType, :Modified)
        |> Audit.add(description: "Updated self-hosted agent type #{agent_type_name}")
        |> Audit.add(resource_name: agent_type_name)
        |> Audit.log()

        res

      other ->
        other
    end
  end

  def agents(conn, params = %{"self_hosted_agent_id" => agent_type_name}) do
    {:ok, agent_type} = AgentType.find(org_id(conn), agent_type_name)
    cursor = if Map.has_key?(params, "cursor"), do: params["cursor"], else: ""
    {:ok, agents, next_cursor} = AgentType.list_agents(org_id(conn), agent_type_name, cursor)

    response =
      if conn.assigns.permissions["organization.self_hosted_agents.view"] do
        %{
          agents: agents,
          first_page_url: first_page_url(agent_type_name),
          next_page_url: next_page_url(next_cursor, agent_type_name),
          total_agents: agent_type.total_agent_count
        }
      else
        %{}
      end

    json(conn, response)
  end

  defp build_agent_type(agent_type) do
    %{
      name: agent_type.name,
      organization_id: agent_type.organization_id,
      total_agent_count: agent_type.total_agent_count,
      requester_id: agent_type.requester_id,
      created_at: agent_type.created_at,
      updated_at: agent_type.updated_at,
      settings: agent_type_model(agent_type)
    }
  end

  def show(conn, %{"id" => agent_type_name, "format" => "json"}) do
    {:ok, agent_type} = AgentType.find(org_id(conn), agent_type_name)
    {:ok, agents, next_cursor} = AgentType.list_agents(org_id(conn), agent_type_name)

    conn
    |> json(%{
      agent_type: build_agent_type(agent_type),
      agents: agents,
      first_page_url: first_page_url(agent_type_name),
      next_page_url: next_page_url(next_cursor, agent_type_name)
    })
  end

  def show(conn, %{"id" => agent_type_name}) do
    {:ok, agent_type} = AgentType.find(org_id(conn), agent_type_name)
    {:ok, agents, next_cursor} = AgentType.list_agents(org_id(conn), agent_type_name)

    render(conn, "show.html",
      agent_type: agent_type,
      agents: agents,
      first_page_url: first_page_url(agent_type_name),
      next_page_url: next_page_url(next_cursor, agent_type_name),
      permissions: conn.assigns.permissions,
      token: nil,
      instructions: "",
      title: "#{agent_type_name}・Self Hosted Agents・Semaphore",
      js: :self_hosted_agents_show
    )
  end

  def confirm_delete(conn, %{"self_hosted_agent_id" => agent_type_name}) do
    {:ok, agent_type} = AgentType.find(org_id(conn), agent_type_name)

    render(conn, "confirm_delete.html",
      agent_type: agent_type,
      title: "Deleting #{agent_type_name}・Self Hosted Agents・Semaphore"
    )
  end

  def confirm_reset_token(conn, %{"self_hosted_agent_id" => agent_type_name}) do
    {:ok, agent_type} = AgentType.find(org_id(conn), agent_type_name)

    render(conn, "confirm_reset_token.html",
      agent_type: agent_type,
      title: "Reset token for #{agent_type_name}・Self Hosted Agents・Semaphore"
    )
  end

  def confirm_disable_all(conn, %{"self_hosted_agent_id" => agent_type_name}) do
    {:ok, agent_type} = AgentType.find(org_id(conn), agent_type_name)

    render(conn, "confirm_disable_all.html",
      agent_type: agent_type,
      title: "Disable all agents for #{agent_type_name}・Self Hosted Agents・Semaphore"
    )
  end

  def confirm_disable(conn, %{
        "self_hosted_agent_id" => agent_type_name,
        "agent_name" => agent_name
      }) do
    render(conn, "confirm_disable.html",
      agent_type: agent_type_name,
      agent_name: agent_name,
      title: "Disabling #{agent_name}・Self Hosted Agents・Semaphore"
    )
  end

  def disable_agent(conn, %{
        "self_hosted_agent_id" => agent_type_name,
        "agent_name" => agent_name,
        "format" => "json"
      }) do
    disable_one_agent(conn, agent_type_name, agent_name)
    |> case do
      :ok ->
        conn
        |> json(%{})

      {:error, _reason} ->
        conn
        |> put_status(422)
        |> json(%{
          message: "Something went wrong while disabling this agent."
        })
    end
  end

  def disable_agent(conn, %{"self_hosted_agent_id" => agent_type_name, "agent_name" => agent_name}) do
    disable_one_agent(conn, agent_type_name, agent_name)
    |> case do
      :ok ->
        conn
        |> put_flash(:notice, "Agent #{agent_name} disconnected")
        |> redirect(to: self_hosted_agent_path(conn, :show, agent_type_name))

      {:error, _reason} ->
        path =
          self_hosted_agent_confirm_disable_path(
            conn,
            :confirm_disable,
            agent_type_name,
            agent_name
          )

        conn
        |> put_flash(:alert, "Something went wrong while disabling this agent.")
        |> redirect(to: path)
    end
  end

  defp disable_one_agent(conn, agent_type_name, agent_name) do
    case AgentType.disable_agent(org_id(conn), agent_type_name, agent_name) do
      :ok ->
        conn
        |> Audit.new(:SelfHostedAgent, :Disabled)
        |> Audit.add(description: "Disabled a self-hosted agent")
        |> Audit.add(resource_name: agent_name)
        |> Audit.metadata(agent_type: agent_type_name)
        |> Audit.log()

        :ok

      {:error, reason} ->
        message = "Failed to disconnect agent. "
        message = message <> "org_id: #{org_id(conn)} name: #{agent_name}. "
        message = message <> "Reason: #{inspect(reason)}."

        Logger.error(message)

        {:error, message}
    end
  end

  def delete(conn, %{"id" => agent_type_name, "format" => "json"}) do
    delete_agent_type(conn, agent_type_name)
    |> case do
      :ok ->
        conn
        |> json(%{})

      {:error, _reason} ->
        conn
        |> put_status(422)
        |> json(%{
          message: "Something went wrong while deleting this agent type."
        })
    end
  end

  def delete(conn, %{"id" => agent_type_name}) do
    delete_agent_type(conn, agent_type_name)
    |> case do
      :ok ->
        conn
        |> put_flash(:notice, "Agent type #{agent_type_name} deleted")
        |> redirect(to: self_hosted_agent_path(conn, :index))

      {:error, _reason} ->
        path = self_hosted_agent_confirm_delete_path(conn, :confirm_delete, agent_type_name)

        conn
        |> put_flash(:alert, "Something went wrong while deleting this agent type.")
        |> redirect(to: path)
    end
  end

  defp delete_agent_type(conn, agent_type_name) do
    AgentType.delete(org_id(conn), agent_type_name)
    |> case do
      :ok ->
        conn
        |> Audit.new(:SelfHostedAgentType, :Removed)
        |> Audit.add(description: "Removed a self-hosted agent type")
        |> Audit.add(resource_name: agent_type_name)
        |> Audit.log()

        :ok

      {:error, reason} ->
        message = "Failed to delete agent type. "
        message = message <> "org_id: #{org_id(conn)} name: #{agent_type_name}. "
        message = message <> "Reason: #{inspect(reason)}."
        Logger.error(reason)

        {:error, message}
    end
  end

  def reset_token(conn, params = %{"format" => "json"}) do
    reset_agent_token(conn, params)
    |> case do
      {:ok, token} ->
        conn
        |> json(%{
          token: token
        })

      {:error, _reason} ->
        conn
        |> put_status(422)
        |> json(%{
          message: "Something went wrong while resetting the token for this agent type."
        })
    end
  end

  def reset_token(conn, params) do
    agent_type_name = params["self_hosted_agent_id"]

    {:ok, agent_type} = AgentType.find(org_id(conn), agent_type_name)
    {:ok, agents, next_cursor} = AgentType.list_agents(org_id(conn), agent_type_name)

    reset_agent_token(conn, params)
    |> case do
      {:ok, token} ->
        render(conn, "show.html",
          agent_type: agent_type,
          agents: agents,
          first_page_url: first_page_url(agent_type_name),
          next_page_url: next_page_url(next_cursor, agent_type_name),
          token: token,
          instructions: "token_reset",
          title: "#{agent_type_name}・Self Hosted Agents・Semaphore",
          js: :self_hosted_agents_token_reset
        )

      {:error, reason} ->
        message = "Failed to reset token. "
        message = message <> "org_id: #{org_id(conn)} name: #{agent_type_name}. "
        message = message <> "Reason: #{inspect(reason)}."

        Logger.error(message)

        path =
          self_hosted_agent_confirm_reset_token_path(conn, :confirm_reset_token, agent_type_name)

        conn
        |> put_flash(
          :alert,
          "Something went wrong while resetting the token for this agent type."
        )
        |> redirect(to: path)
    end
  end

  defp reset_agent_token(conn, params) do
    agent_type_name = params["self_hosted_agent_id"]
    disconnect_running_agents = params["disconnect_running_agents"] == "true"
    user_id = conn.assigns.user_id

    AgentType.reset_token(org_id(conn), agent_type_name, disconnect_running_agents, user_id)
    |> case do
      {:ok, token} ->
        conn
        |> Audit.new(:SelfHostedAgentType, :Modified)
        |> Audit.add(description: "Token was reset")
        |> Audit.add(resource_name: agent_type_name)
        |> Audit.log()

        {:ok, token}

      {:error, reason} ->
        message = "Failed to reset token. "
        message = message <> "org_id: #{org_id(conn)} name: #{agent_type_name}. "
        message = message <> "Reason: #{inspect(reason)}."

        Logger.error(message)

        {:error, reason}
    end
  end

  def disable_all_agents(conn, params = %{"format" => "json"}) do
    agent_type_name = params["self_hosted_agent_id"]
    only_idle_agents = params["only_idle_agents"] == "true"

    disable_agents(conn, params)
    |> case do
      :ok ->
        message =
          if only_idle_agents do
            "All idle agents for #{agent_type_name} were disabled"
          else
            "All agents for #{agent_type_name} were disabled"
          end

        conn
        |> json(%{
          message: message
        })

      {:error, _reason} ->
        conn
        |> put_status(422)
        |> json(%{
          message: "Something went wrong while disabling the agents for this agent type."
        })
    end
  end

  def disable_all_agents(conn, params) do
    agent_type_name = params["self_hosted_agent_id"]
    only_idle_agents = params["only_idle_agents"] == "true"

    disable_agents(conn, params)
    |> case do
      :ok ->
        conn
        |> put_flash(
          :notice,
          if only_idle_agents do
            "All idle agents for #{agent_type_name} were disabled"
          else
            "All agents for #{agent_type_name} were disabled"
          end
        )
        |> redirect(to: self_hosted_agent_path(conn, :show, agent_type_name))

      {:error, _reason} ->
        path =
          self_hosted_agent_confirm_disable_all_path(conn, :confirm_disable_all, agent_type_name)

        conn
        |> put_flash(
          :alert,
          "Something went wrong while disabling the agents for this agent type."
        )
        |> redirect(to: path)
    end
  end

  defp disable_agents(conn, params) do
    agent_type_name = params["self_hosted_agent_id"]
    only_idle_agents = params["only_idle_agents"] == "true"

    AgentType.disable_all_agents(org_id(conn), agent_type_name, only_idle_agents)
    |> case do
      :ok ->
        conn
        |> Audit.new(:SelfHostedAgentType, :Disabled)
        |> Audit.add(description: "Disabled all agents for a self-hosted agent type")
        |> Audit.add(resource_name: agent_type_name)
        |> Audit.metadata(only_idle: only_idle_agents)
        |> Audit.log()

        :ok

      {:error, reason} ->
        message = "Failed to disable agents. "
        message = message <> "org_id: #{org_id(conn)} name: #{agent_type_name}. "
        message = message <> "Reason: #{inspect(reason)}."

        Logger.error(message)

        {:error, reason}
    end
  end

  defp org_id(conn), do: conn.assigns.organization_id

  defp authorize_feature(conn, _opts) do
    cond do
      FeatureProvider.feature_enabled?(:self_hosted_agents, org_id(conn)) ->
        conn

      FeatureProvider.feature_zero_state?(:self_hosted_agents, org_id(conn)) ->
        conn
        |> render("zero_state.html",
          conn: conn,
          title: "Self Hosted Agents・Semaphore",
          layout: {FrontWeb.LayoutView, "organization.html"}
        )

      true ->
        conn
        |> FrontWeb.PageController.status404(%{})
        |> Plug.Conn.halt()
    end
  end

  defp first_page_url(agent_type_name), do: "/self_hosted_agents/#{agent_type_name}/agents"
  defp next_page_url("", _agent_type_name), do: ""

  defp next_page_url(cursor, agent_type_name),
    do: "/self_hosted_agents/#{agent_type_name}/agents?cursor=#{cursor}"
end
