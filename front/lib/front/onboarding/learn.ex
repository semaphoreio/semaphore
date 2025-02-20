defmodule Front.Onboarding.Learn do
  alias __MODULE__

  @type t :: %Learn{
          sections: [Learn.Section.t()],
          progress: Learn.Progress.t()
        }

  defstruct [:sections, :progress]

  @spec load(String.t(), String.t()) :: t()
  def load(organization_id, user_id) do
    sections = Learn.Section.load(organization_id, user_id)
    progress = Learn.Progress.load(sections, organization_id, user_id)

    %Learn{
      sections: sections,
      progress: progress
    }
  end

  @spec mark(String.t(), String.t(), String.t()) :: :ok
  def mark(event_id, organization_id, user_id) do
    {:ok, _} =
      Front.Clients.Scouter.signal(
        %{organization_id: organization_id, user_id: user_id},
        event_id
      )

    :ok
  end

  @spec has_event?(String.t(), String.t(), String.t()) :: boolean()
  def has_event?(event_id, organization_id, user_id) do
    Front.Clients.Scouter.list(%{organization_id: organization_id, user_id: user_id}, [event_id])
    |> case do
      {:ok, events} ->
        Enum.any?(events, &(&1.id == event_id))

      _ ->
        false
    end
  end
end
