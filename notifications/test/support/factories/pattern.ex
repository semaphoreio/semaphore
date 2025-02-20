defmodule Support.Factories.Pattern do
  def build(_name, params \\ %{}) do
    Map.merge(
      %{
        org_id: Ecto.UUID.generate(),
        rule_id: Ecto.UUID.generate()
      },
      params
    )
  end
end
