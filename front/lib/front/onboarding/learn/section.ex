defmodule Front.Onboarding.Learn.Section do
  require Logger
  alias Front.Onboarding.Learn

  @type lock_type() :: :feature | :permission | :progress
  @type task :: %{
          name: String.t(),
          id: String.t(),
          description: String.t(),
          event_id: String.t(),
          required_features: [String.t()],
          required_permissions: [String.t()],
          completed: boolean(),
          completed_at: nil | DateTime.t(),
          locked: [Learn.lock_type()]
        }

  @type t :: %Learn.Section{
          name: String.t(),
          id: String.t(),
          description: String.t(),
          depends_on: [String.t()],
          required_features: [String.t()],
          required_permissions: [String.t()],
          completed: boolean(),
          duration: String.t(),
          tasks: [task()],
          locked: [lock_type()]
        }

  defstruct [
    :name,
    :id,
    :description,
    :depends_on,
    :required_features,
    :required_permissions,
    :completed,
    :duration,
    :tasks,
    :locked
  ]

  @spec load(String.t(), String.t()) :: [t()]
  def load(organization_id, user_id) do
    load_sections()
    |> check_features(organization_id)
    |> check_permissions(organization_id, user_id)
    |> filter_locked()
    |> preload_state(organization_id, user_id)
    |> organize_dependencies()
  end

  @spec parse(section :: map) :: t()
  def parse(section) do
    id = Map.get(section, "id")
    name = Map.get(section, "name")
    description = Map.get(section, "description")
    depends_on = Map.get(section, "depends_on", [])
    duration = Map.get(section, "duration")
    tasks = Map.get(section, "tasks", []) |> Enum.map(&parse_task/1)
    required_features = Map.get(section, "required_features", [])
    required_permissions = Map.get(section, "required_permissions", [])
    completed = Map.get(section, "completed", false)

    %Learn.Section{
      name: name,
      id: id,
      description: description,
      depends_on: depends_on,
      duration: duration,
      tasks: tasks,
      required_features: required_features,
      required_permissions: required_permissions,
      completed: completed,
      locked: []
    }
  end

  @spec load_sections() :: [t()]
  defp load_sections do
    Application.get_env(:front, :get_started_path)
    |> YamlElixir.read_from_file()
    |> case do
      {:ok, sections} ->
        Enum.map(sections, &parse/1)

      {:error, e} ->
        Logger.error("Failed to load onboarding sections: #{inspect(e)}")
        []
    end
  end

  @spec filter_locked(sections :: [t()]) :: [t()]
  defp filter_locked(sections) do
    sections
    |> Enum.reject(fn section ->
      :permission in section.locked or :feature in section.locked
    end)
    |> Enum.map(fn section ->
      filtered_tasks =
        section.tasks
        |> Enum.reject(fn task ->
          :permission in task.locked or :feature in task.locked
        end)

      section = %{section | tasks: filtered_tasks}

      if section.tasks == [],
        do: nil,
        else: section
    end)
    |> Enum.filter(& &1)
  end

  @spec preload_state([t()], String.t(), String.t()) :: [t()]
  defp preload_state(sections, organization_id, user_id) do
    event_ids =
      sections
      |> Enum.flat_map(fn section -> Enum.map(section.tasks, & &1.event_id) end)
      |> Enum.uniq()

    {:ok, events} =
      Front.Clients.Scouter.list(%{organization_id: organization_id, user_id: user_id}, event_ids)

    sections
    |> Enum.map(fn section ->
      tasks_with_completions =
        section.tasks
        |> Enum.map(fn task ->
          event = Enum.find(events, &(&1.id == task.event_id))

          if event,
            do: %{
              task
              | completed: true,
                completed_at: DateTime.from_unix!(event.occured_at.seconds)
            },
            else: task
        end)

      %{
        section
        | tasks: tasks_with_completions,
          completed: task_completed?(tasks_with_completions)
      }
    end)
  end

  @spec parse_task(task :: map) :: task()
  defp parse_task(task) do
    id = Map.get(task, "id")
    name = Map.get(task, "name")
    description = Map.get(task, "description")
    event_id = Map.get(task, "event_id")
    required_features = Map.get(task, "required_features", [])
    required_permissions = Map.get(task, "required_permissions", [])

    %{
      name: name,
      id: id,
      description: description,
      event_id: event_id,
      required_features: required_features,
      required_permissions: required_permissions,
      completed: false,
      completed_at: nil,
      locked: []
    }
  end

  @spec check_features([t()], String.t()) :: [t()]
  defp check_features(sections, organization_id) do
    sections
    |> Enum.map(fn section ->
      tasks_with_locks =
        section.tasks
        |> Enum.map(fn task ->
          all_features_enabled? =
            Enum.all?(section.required_features, fn feature ->
              FeatureProvider.feature_enabled?(feature, organization_id)
            end)

          if all_features_enabled?,
            do: task,
            else: %{task | locked: [:feature | task.locked]}
        end)

      section = %{section | tasks: tasks_with_locks}

      all_features_enabled? =
        Enum.all?(section.required_features, fn feature ->
          FeatureProvider.feature_enabled?(feature, organization_id)
        end)

      if all_features_enabled?,
        do: section,
        else: %{section | locked: [:feature | section.locked]}
    end)
  end

  @spec check_permissions([t()], String.t(), String.t()) :: [t()]
  defp check_permissions(sections, organization_id, user_id) do
    sections
    |> Enum.map(fn section ->
      tasks_with_locks =
        section.tasks
        |> Enum.map(fn task ->
          has_all_permissions? =
            Enum.all?(task.required_permissions, fn permission ->
              Front.RBAC.Permissions.has?(user_id, organization_id, permission)
            end)

          if has_all_permissions?,
            do: task,
            else: %{task | locked: [:permission | task.locked]}
        end)

      section = %{section | tasks: tasks_with_locks}

      has_all_permissions? =
        Enum.all?(section.required_permissions, fn permission ->
          Front.RBAC.Permissions.has?(user_id, organization_id, permission)
        end)

      if has_all_permissions?,
        do: section,
        else: %{section | locked: [:permission | section.locked]}
    end)
  end

  @spec organize_dependencies([t()]) :: [t()]
  defp organize_dependencies(sections) do
    sections
    |> Enum.reduce([], fn section, sections ->
      sections
      |> case do
        [] ->
          [section]

        sections when section.depends_on == [] ->
          [section | sections]

        sections when section.depends_on != [] ->
          dependant_sections =
            Enum.filter(sections, fn s ->
              s.id in section.depends_on
            end)

          section =
            if section_completed?(dependant_sections) do
              section
            else
              %{
                section
                | tasks:
                    Enum.map(section.tasks, fn task ->
                      %{task | locked: [:progress | task.locked]}
                    end)
              }
            end

          [section | sections]
      end
    end)
    |> Enum.reverse()
  end

  defp section_completed?(sections) when is_list(sections) do
    sections
    |> Enum.flat_map(& &1.tasks)
    |> Enum.all?(&task_completed?/1)
  end

  defp task_completed?(tasks) when is_list(tasks), do: Enum.all?(tasks, &task_completed?/1)
  defp task_completed?(task), do: task.completed
end
