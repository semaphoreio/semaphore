defmodule Front.Models.DeploymentDetails do
  alias Front.Models.Pipeline
  alias Front.Models.RepoProxy
  alias Front.Models.User

  defmodule Deployment do
    use TypedStruct

    typedstruct do
      field(:id, String.t())
      field(:state, atom())
      field(:pipeline_id, String.t())
      field(:pipeline, map())
      field(:hook, map())
      field(:env_vars, [map()])
      field(:can_rerun?, [boolean()])

      field(:switch_id, String.t())
      field(:target_name, String.t())
      field(:triggered_at, DateTime.t())
      field(:triggered_by, String.t())
      field(:author_name, String.t())
      field(:author_avatar_url, String.t())
    end

    def construct(deployment) do
      %__MODULE__{
        id: deployment.id,
        triggered_by: deployment.triggered_by,
        triggered_at: deployment.triggered_at.seconds,
        state: deployment.state,
        pipeline_id: construct_pipeline_id(deployment),
        switch_id: deployment.switch_id,
        target_name: deployment.target_name,
        env_vars: deployment.env_vars,
        can_rerun?: deployment.can_requester_rerun
      }
    end

    defp construct_pipeline_id(deployment) do
      if deployment.pipeline_id == "",
        do: deployment.prev_pipeline_id,
        else: deployment.pipeline_id
    end

    def preload_pipeline(deployment = %__MODULE__{}, pipeline = %Pipeline{}) do
      %__MODULE__{deployment | pipeline: pipeline}
    end

    def preload_hook(deployment = %__MODULE__{}, hook = %RepoProxy{}) do
      %__MODULE__{deployment | hook: hook}
    end

    def preload_triggerer(deployment = %__MODULE__{triggered_by: "Pipeline Done request"}, nil) do
      avatar_url = "#{FrontWeb.SharedHelpers.assets_path()}/images/profile-bot.svg"
      %__MODULE__{deployment | author_name: "Auto-promotion", author_avatar_url: avatar_url}
    end

    def preload_triggerer(deployment = %__MODULE__{}, user = %User{}) do
      %__MODULE__{deployment | author_name: user.name, author_avatar_url: user.avatar_url}
    end

    def preload_triggerer(deployment = %__MODULE__{}, nil) do
      %__MODULE__{
        deployment
        | author_name: Application.get_env(:front, :default_user_name),
          author_avatar_url: FrontWeb.SharedHelpers.assets_path() <> "/images/org-s.svg"
      }
    end
  end

  defmodule HistoryPage do
    use TypedStruct

    typedstruct do
      field(:deployments, [Deployments.t()])
      field(:cursor_before, integer())
      field(:cursor_after, integer())
    end

    def construct(args),
      do: construct(args[:deployments], args[:cursor_before], args[:cursor_after])

    def construct(deployments, cursor_before, cursor_after) do
      %__MODULE__{
        deployments: Enum.into(deployments, [], &Deployment.construct/1),
        cursor_before: if(cursor_before > 0, do: cursor_before, else: nil),
        cursor_after: if(cursor_after > 0, do: cursor_after, else: nil)
      }
    end

    def load(page = %__MODULE__{}) do
      page
      |> preload_pipelines()
      |> preload_hooks()
      |> preload_triggerers()
    end

    defp preload_pipelines(page = %__MODULE__{}) do
      pipelines =
        page.deployments
        |> Stream.map(& &1.pipeline_id)
        |> Enum.to_list()
        |> Front.Models.Pipeline.find_many()
        |> Map.new(&{&1.id, &1})

      deployments =
        page.deployments
        |> Enum.into([], fn deployment ->
          pipeline = Map.get(pipelines, deployment.pipeline_id)
          Deployment.preload_pipeline(deployment, pipeline)
        end)

      %__MODULE__{page | deployments: deployments}
    end

    def preload_hooks(page = %__MODULE__{}) do
      hooks =
        page.deployments
        |> Stream.filter(& &1.pipeline)
        |> Stream.map(& &1.pipeline.hook_id)
        |> Enum.to_list()
        |> Front.Models.RepoProxy.find()
        |> Map.new(&{&1.id, &1})

      deployments =
        page.deployments
        |> Enum.into([], fn deployment ->
          hook = Map.get(hooks, deployment.pipeline.hook_id)
          Deployment.preload_hook(deployment, hook)
        end)

      %__MODULE__{page | deployments: deployments}
    end

    def preload_triggerers(page = %__MODULE__{}) do
      triggerers =
        page.deployments
        |> Stream.map(& &1.triggered_by)
        |> Enum.reject(&String.equivalent?(&1, "Pipeline Done request"))
        |> Front.Models.User.find_many()
        |> Map.new(&{&1.id, &1})

      deployments =
        page.deployments
        |> Enum.into([], fn deployment ->
          triggerer = Map.get(triggerers, deployment.triggered_by)
          Deployment.preload_triggerer(deployment, triggerer)
        end)

      %__MODULE__{page | deployments: deployments}
    end
  end

  use TypedStruct

  typedstruct do
    field(:id, String.t())
    field(:name, String.t())
    field(:description, String.t())
    field(:url, String.t())

    field(:organization_id, String.t())
    field(:project_id, String.t())

    field(:parameter_name_1, String.t())
    field(:parameter_name_2, String.t())
    field(:parameter_name_3, String.t())

    field(:created_at, String.t())
    field(:created_by, String.t())

    field(:updated_at, String.t())
    field(:updated_by, String.t())

    field(:for_everyone?, [boolean()])
    field(:role_ids, [String.t()])
    field(:member_ids, [String.t()])

    field(:members, [%User{}])
    field(:updator, [%User{}])
    field(:role_names, [String.t()])

    field(:branch_mode, [atom()])
    field(:tag_mode, [atom()])
    field(:pr_mode, [atom()])

    field(:state, atom())
    field(:cordoned?, boolean())
    field(:last_deployment, Deployment.t())
    field(:history_page, HistoryPage.t())
  end

  # constructors

  def load(target, history_page = %HistoryPage{}),
    do: %__MODULE__{construct(target) | history_page: HistoryPage.load(history_page)}

  def load(targets) when is_list(targets) do
    targets
    |> construct()
    |> preload_pipelines()
    |> preload_hooks()
    |> preload_roles()
    |> preload_users()
  end

  def construct(targets) when is_list(targets) do
    Enum.into(targets, [], &construct/1)
  end

  def construct(target) do
    last_deployment = target.last_deployment && Deployment.construct(target.last_deployment)

    %__MODULE__{
      id: target.id,
      name: target.name,
      description: target.description,
      url: target.url,
      organization_id: target.organization_id,
      project_id: target.project_id,
      parameter_name_1: target.bookmark_parameter1,
      parameter_name_2: target.bookmark_parameter2,
      parameter_name_3: target.bookmark_parameter3,
      created_at: target.created_at.seconds,
      created_by: target.created_by,
      updated_at: target.updated_at.seconds,
      updated_by: target.updated_by,
      for_everyone?: has_any_subject_rule?(target.subject_rules),
      role_ids: subject_ids(target.subject_rules, :ROLE),
      member_ids: subject_ids(target.subject_rules, :USER),
      branch_mode: object_mode(target.object_rules, :BRANCH),
      tag_mode: object_mode(target.object_rules, :TAG),
      pr_mode: object_mode(target.object_rules, :PR),
      state: target.state,
      cordoned?: target.cordoned,
      last_deployment: last_deployment
    }
  end

  defp has_any_subject_rule?(subject_rules),
    do: Enum.any?(subject_rules, &(&1.type == :ANY))

  defp subject_ids(subject_rules, type) do
    subject_rules
    |> Stream.filter(&(&1.type == type))
    |> Enum.into([], & &1.subject_id)
  end

  defp object_mode(object_rules, type) do
    object_items =
      object_rules
      |> Stream.filter(&(&1.type == type))
      |> Enum.into([], &Map.take(&1, ~w(match_mode pattern)a))

    all_match_modes = MapSet.new(object_items, & &1.match_mode)

    cond do
      MapSet.member?(all_match_modes, :ALL) -> :ALL
      Enum.empty?(all_match_modes) -> :NONE
      true -> :WHITELISTED
    end
  end

  def preload_pipelines(targets) when is_list(targets) do
    pipelines =
      targets
      |> Stream.filter(& &1.last_deployment)
      |> Stream.map(& &1.last_deployment.pipeline_id)
      |> Enum.to_list()
      |> Front.Models.Pipeline.find_many()
      |> Map.new(&{&1.id, &1})

    Enum.into(targets, [], fn target ->
      if target.last_deployment do
        pipeline = Map.get(pipelines, target.last_deployment.pipeline_id)
        last_deployment = Deployment.preload_pipeline(target.last_deployment, pipeline)
        %__MODULE__{target | last_deployment: last_deployment}
      else
        target
      end
    end)
  end

  def preload_roles(targets = []), do: targets

  def preload_roles(targets) when is_list(targets) do
    org_id = targets |> List.first() |> Map.get(:organization_id)
    {:ok, roles} = Front.RBAC.RoleManagement.list_possible_roles(org_id, "project_scope")
    roles = Map.new(roles, &{&1.id, &1.name})

    Enum.into(targets, [], fn target ->
      role_names = roles |> Map.take(target.role_ids) |> Map.values()
      %__MODULE__{target | role_names: role_names}
    end)
  end

  def preload_hooks(targets) when is_list(targets) do
    hooks =
      targets
      |> Stream.filter(& &1.last_deployment)
      |> Stream.filter(& &1.last_deployment.pipeline)
      |> Stream.map(& &1.last_deployment.pipeline.hook_id)
      |> Enum.to_list()
      |> Front.Models.RepoProxy.find()
      |> Map.new(&{&1.id, &1})

    Enum.into(targets, [], fn target ->
      if target.last_deployment && target.last_deployment.pipeline do
        hook = Map.get(hooks, target.last_deployment.pipeline.hook_id)
        last_deployment = Deployment.preload_hook(target.last_deployment, hook)
        %__MODULE__{target | last_deployment: last_deployment}
      else
        target
      end
    end)
  end

  def preload_users(targets) when is_list(targets) do
    users =
      targets
      |> Stream.filter(& &1.last_deployment)
      |> Stream.map(& &1.last_deployment.triggered_by)
      |> Stream.reject(&String.equivalent?(&1, "Pipeline Done request"))
      |> Stream.concat(Stream.flat_map(targets, & &1.member_ids))
      |> Stream.concat(Stream.map(targets, & &1.updated_by))
      |> Enum.to_list()
      |> Front.Models.User.find_many()
      |> Map.new(&{&1.id, &1})

    Enum.into(targets, [], fn target ->
      updator = Map.get(users, target.updated_by)
      members = users |> Map.take(target.member_ids) |> Map.values()

      last_deployment =
        if target.last_deployment do
          triggerer = Map.get(users, target.last_deployment.triggered_by)
          Deployment.preload_triggerer(target.last_deployment, triggerer)
        else
          target.last_deployment
        end

      %{target | updator: updator, members: members, last_deployment: last_deployment}
    end)
  end
end
