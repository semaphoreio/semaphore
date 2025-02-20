defmodule Scouter.Storage.EventQueries do
  import Ecto.Query

  def create(context, event_id) do
    organization_id = Map.get(context, :organization_id)
    project_id = Map.get(context, :project_id)

    user_id =
      Map.get(context, :user_id)

    %Scouter.Storage.Event{}
    |> Scouter.Storage.Event.changeset(%{
      event_id: event_id,
      organization_id: organization_id,
      project_id: project_id,
      user_id: user_id
    })
    |> Scouter.Repo.insert(on_conflict: :nothing)
    |> resolve_errors()
  end

  def list(context, event_ids \\ []) do
    organization_id = Map.get(context, :organization_id)
    project_id = Map.get(context, :project_id)
    user_id = Map.get(context, :user_id)

    query =
      from(Scouter.Storage.Event)

    query =
      if organization_id,
        do: where(query, [e], e.organization_id == ^organization_id),
        else: query

    query =
      if project_id,
        do: where(query, [e], e.project_id == ^project_id),
        else: query

    query =
      if user_id,
        do: where(query, [e], e.user_id == ^user_id),
        else: query

    event_ids
    |> case do
      [] -> query
      event_ids -> where(query, [e], e.event_id in ^event_ids)
    end
    |> Scouter.Repo.all()
  end

  def resolve_errors({:ok, changeset}), do: {:ok, changeset}

  def resolve_errors({:error, changeset}) do
    error_messages =
      changeset.errors
      |> Enum.map(fn
        {:base, {message, _opts}} ->
          message

        {key, {message, _opts}} ->
          "#{key} #{message}"
      end)

    {:error, Enum.join(error_messages, ", ")}
  end
end
