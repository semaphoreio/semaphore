defmodule Support.Factories.Rule do
  def build(name, params \\ %{}) do
    Map.merge(
      %{
        org_id: Ecto.UUID.generate(),
        notification_id: Ecto.UUID.generate(),
        name: name
      },
      params
    )
  end
end
