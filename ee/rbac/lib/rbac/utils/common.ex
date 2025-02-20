defmodule Rbac.Utils.Common do
  def nil_uuid, do: "00000000-0000-0000-0000-000000000000"

  def valid_uuid?(uuid) do
    Ecto.UUID.dump!(uuid)
    true
  rescue
    _ -> false
  end
end
