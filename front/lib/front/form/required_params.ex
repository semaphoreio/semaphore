defmodule Front.Form.RequiredParams do
  import Ecto.Changeset

  @doc """
  This module should be used to validate the required form inputs
  Example usage:

    Front.Form.RequiredParams.create_changeset(
      %__MODULE{},
      params,
      [:name]
    )
  """

  def create_changeset(params \\ %{}, required_fields, module) do
    module
    |> cast(params, required_fields)
    |> validate_required(required_fields, message: "Required. Cannot be empty.")
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
end
