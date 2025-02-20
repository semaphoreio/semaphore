defmodule Rbac.Okta.Scim.Filter do
  @moduledoc """
  This is the poor mans implementation for supporting SCIM filters.
  This is enough for the Okta integration, but for some other SCIM
  providers it might not be enough.

  Here is a full parser example:
  https://github.com/scim2/filter-parser
  """

  @type t :: %{
          field_name: String.t(),
          value: any(),
          comparator: :eq
        }

  def compute(nil) do
    []
  end

  def compute(filter) do
    captures = Regex.run(~r/userName eq "(.*)"/, filter)

    case captures do
      [_, user_name] ->
        [
          %{
            :field_name => :username,
            :value => user_name,
            :comparator => :eq
          }
        ]

      nil ->
        []
    end
  end
end
