defmodule Dashboardhub.Repo do
  use Ecto.Repo,
    otp_app: :dashboardhub,
    adapter: Ecto.Adapters.Postgres

  use Paginator

  defmodule Dashboard do
    use Ecto.Schema
    import Ecto.Changeset

    alias Dashboardhub.Utils

    @primary_key {:id, :binary_id, autogenerate: true}

    schema "dashboards" do
      field(:org_id, :binary_id)
      field(:name, :string)
      field(:content, :map)

      timestamps()
    end

    def changeset(dashboard, params \\ %{}) do
      dashboard
      |> cast(params, [:org_id, :name, :content])
      |> validate_required([:org_id, :name, :content])
      |> valid_name_format(params)
      |> unique_constraint(:unique_names,
        name: :unique_names_in_organization,
        message: "name has already been taken"
      )
    end

    defp valid_name_format(changeset, params) do
      cond do
        Utils.uuid?(params.name) ->
          changeset |> add_error(:name_format, "name should not be in uuid format")

        !String.match?(params.name, ~r/\A(?!-)[a-z0-9\-]+\z/) ->
          changeset
          |> add_error(
            :name_format,
            "name should contain only lowercase letters a-z, numbers 0-9, and dashes, no spaces"
          )

        true ->
          changeset
      end
    end
  end
end
