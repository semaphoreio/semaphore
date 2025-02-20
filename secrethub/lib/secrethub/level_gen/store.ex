defmodule Secrethub.LevelGen.Store do
  alias Secrethub.LevelGen.Util

  defmacro __using__(opts) do
    model = Util.get_mandatory_field(opts, :model)

    quote do
      alias unquote(model), as: Secret
      alias Secrethub.Model.Checkout
      alias Secrethub.Model.Content
      alias Secrethub.Model.EnvVar
      alias Secrethub.Model.File
      alias Secrethub.Repo
      require Ecto.Query

      def list_by_ids([]), do: []

      def list_by_ids(ids) do
        Secret
        |> Ecto.Query.where([s], s.id in ^ids)
        |> Repo.all()
        |> decrypt_many(false)
      end

      def find_by_id(_org_id, _project_id, nil), do: {:error, :not_found}
      def find_by_id(_org_id, _project_id, ""), do: {:error, :not_found}

      def find_by_id(org_id, project_id, id) do
        res =
          by_project_id(project_id)
          |> Ecto.Query.where([s], s.org_id == ^org_id)
          |> Ecto.Query.where([s], s.id == ^id)
          |> Repo.one()

        case res do
          nil -> {:error, :not_found}
          secret -> Secrethub.Encryptor.decrypt_secret(secret)
        end
      end

      defp by_project_id(:skip), do: Secret

      defp by_project_id(project_id) do
        Secret
        |> Ecto.Query.where([s], s.project_id == ^project_id)
      end

      def checkout(secret = %Secret{}, checkout) do
        used_at = DateTime.utc_now() |> DateTime.truncate(:second)

        secret
        |> Secret.checkout_changeset(%{
          used_by: checkout,
          used_at: used_at
        })
        |> Repo.update()
        |> case do
          {:ok, secret} -> Secrethub.Encryptor.decrypt_secret(secret)
          e -> e
        end
      end

      def checkout_many(secrets, checkout) do
        secret_ids = Enum.into(secrets, [], & &1.id)
        used_by = Checkout.from_params(checkout)
        used_at = DateTime.utc_now() |> DateTime.truncate(:second)

        Repo.update_all(
          Ecto.Query.from(s in Secret)
          |> Ecto.Query.where([s], s.id in ^secret_ids)
          |> Ecto.Query.select([s], s),
          [set: [used_at: used_at, used_by: used_by]],
          returning: true
        )
        |> case do
          {:error, e} -> e
          {_, secrets} -> decrypt_many(secrets, false)
        end
      end

      def create(params) do
        %Secret{}
        |> Secret.changeset(params)
        |> Repo.insert()
        |> case do
          {:ok, secret} -> Secrethub.Encryptor.decrypt_secret(secret)
          e -> e
        end
      end

      def update(secret = %Secret{}, params) do
        secret
        |> Secret.changeset(params)
        |> Repo.update()
        |> case do
          {:ok, secret} -> Secrethub.Encryptor.decrypt_secret(secret)
          e -> e
        end
      end

      def delete(secret = %Secret{}) do
        Repo.delete(secret)
      end

      def decrypt_many(secrets, ignore_contents? = true), do: secrets

      def decrypt_many(secrets, ignore_contents? = false) do
        Enum.map(secrets, fn secret ->
          case Secrethub.Encryptor.decrypt_secret(secret) do
            {:ok, secret} -> secret
            _ -> nil
          end
        end)
      end
    end
  end
end
