defmodule Support.Factories.EphemeralEnvironmentsType do
  @moduledoc """
  Factory for creating EphemeralEnvironmentType records in tests.

  ## Usage

      # Create with defaults
      {:ok, env_type} = Support.Factories.EphemeralEnvironmentsType.insert()

      # Create with custom attributes
      {:ok, env_type} = Support.Factories.EphemeralEnvironmentsType.insert(
        org_id: "some-org-id",
        name: "My Environment",
        description: "Custom description",
        created_by: "user-id",
        state: :ready,
        max_number_of_instances: 10
      )
  """

  def insert(options \\ []) do
    attrs = %{
      org_id: get_id(options[:org_id]),
      name: get_name(options[:name]),
      description: options[:description],
      created_by: get_id(options[:created_by]),
      last_updated_by: get_id(options[:created_by]),
      state: options[:state] || :draft,
      max_number_of_instances: options[:max_number_of_instances] || 1
    }

    %EphemeralEnvironments.Repo.EphemeralEnvironmentType{}
    |> EphemeralEnvironments.Repo.EphemeralEnvironmentType.changeset(attrs)
    |> EphemeralEnvironments.Repo.insert()
  end

  defp get_id(nil), do: Ecto.UUID.generate()
  defp get_id(id), do: id

  defp get_name(nil), do: "env-" <> random_string(10)
  defp get_name(name), do: name

  defp random_string(length) do
    for(_ <- 1..length, into: "", do: <<Enum.random(~c"abcdefghijklmnopqrstuvwxyz0123456789")>>)
  end
end
