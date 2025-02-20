defmodule Front.ProjectSettings.DeletionValidator do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field(:delete_confirmation, :string)
    field(:feedback, :string)
    field(:reason, :string)
  end

  def run(project, params) do
    %__MODULE__{}
    |> cast(params, [:delete_confirmation, :feedback, :reason])
    |> validate_project_name(project.name)
    |> validate_required(:reason, message: "Please select reason.")
    |> validate_feedback_for_new_projects(project.created_at)
    |> set_feedback_if_missing
    |> parse
  end

  defp parse(changeset) do
    %{
      valid?: changeset.valid?,
      errors: Enum.map(changeset.errors, fn e -> parse_error_msg(e) end),
      changes: changeset.changes
    }
  end

  defp parse_error_msg({attribute, {message, _}}) do
    {attribute, message}
  end

  # Feedback is required if project is added in the last 7 days
  defp validate_feedback_for_new_projects(changeset, timestamp) do
    with true <- in_last_7_days?(timestamp),
         nil <- get_field(changeset, :feedback) do
      add_error(changeset, :feedback, "Would you mind sharing how can we improve Semaphore?")
    else
      _e ->
        changeset
    end
  end

  defp set_feedback_if_missing(changeset) do
    with nil <- get_field(changeset, :feedback) do
      put_change(changeset, :feedback, "N/A")
    else
      _e ->
        changeset
    end
  end

  defp validate_project_name(changeset, project_name) do
    confirmation = get_field(changeset, :delete_confirmation)

    if confirmation != project_name do
      add_error(changeset, :delete_confirmation, "Name does not match.")
    else
      changeset
    end
  end

  def in_last_7_days?(timestamp) do
    difference = Timex.diff(Timex.now(), timestamp, :days)
    difference <= 7
  end
end
