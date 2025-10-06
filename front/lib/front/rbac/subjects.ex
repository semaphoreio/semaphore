defmodule Front.RBAC.Subjects do
  require Logger

  def list_subjects(org_id, subject_ids) when is_list(subject_ids) do
    if Enum.empty?(subject_ids) do
      {:ok, %{}}
    else
      req = InternalApi.RBAC.ListSubjectsRequest.new(org_id: org_id, subject_ids: subject_ids)

      Front.RBAC.Client.channel()
      |> InternalApi.RBAC.RBAC.Stub.list_subjects(req, timeout: 30_000)
      |> case do
        {:ok, resp} ->
          subjects_map =
            resp.subjects
            |> Enum.map(fn subject ->
              {subject.subject_id,
               %{
                 id: subject.subject_id,
                 type: parse_subject_type(subject.subject_type),
                 display_name: subject.display_name
               }}
            end)
            |> Map.new()

          {:ok, subjects_map}

        {:error, error} ->
          Logger.error("Error fetching subjects for org #{org_id}: #{inspect(error)}")
          {:error, error.message}
      end
    end
  end

  def list_subjects(_org_id, _subject_ids), do: {:ok, %{}}

  defp parse_subject_type(subject_type) do
    case InternalApi.RBAC.SubjectType.key(subject_type) do
      :USER -> "user"
      :GROUP -> "group"
      :SERVICE_ACCOUNT -> "service_account"
      _ -> "unknown"
    end
  end
end
