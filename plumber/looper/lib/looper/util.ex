defmodule Looper.Util do
  @moduledoc """
  Called from different modules.
  """

  def get_mandatory_field(keywords, field_name) when is_list(keywords), do:
    keywords[field_name] || missing_field(field_name)

  def missing_field(field_name), do: raise "'#{field_name}' field is mandatory"

  def get_optional_field(keywords, field_name, default \\ nil) when is_list(keywords), do:
    keywords[field_name] || default

  def return_ok_tuple(value), do: {:ok, value}
  def return_error_tuple(value), do: {:error, value}

  def get_alias(full_name) when is_atom(full_name), do:
    full_name |> Atom.to_string() |> String.split(".") |> List.last()

  def clean_test_db() do
    Ecto.Adapters.SQL.query(Looper.Test.EctoRepo, "truncate table items cascade;")
    Ecto.Adapters.SQL.query(Looper.Test.EctoRepo, "truncate table entities cascade;")
    Ecto.Adapters.SQL.query(Looper.Test.EctoRepo, "truncate table entity_traces cascade;")
  end

end
