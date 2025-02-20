# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule Support.PrepareFunctions do
  defmacro __using__(api) do
    quote do
      alias Secrethub.Repo
      alias Support.Factories.Model, as: ModelFactory
      alias Secrethub.ProjectSecrets.Secret

      alias unquote(api), as: API

      defp repo_checkout(_context) do
        :ok = Ecto.Adapters.SQL.Sandbox.checkout(Secrethub.Repo)
      end

      defp prepare_data(_ctx) do
        {:ok,
         project_id: Ecto.UUID.generate(),
         org_id: Ecto.UUID.generate(),
         user_id: Ecto.UUID.generate(),
         now: DateTime.utc_now()}
      end

      defp prepare_secret(ctx) do
        name = "dt.#{ctx.project_id}"
        content = ModelFactory.prepare_content()

        case Secrethub.Encryptor.encrypt(Poison.encode!(content), name) do
          {:ok, encrypted} ->
            {:ok,
             secret:
               Repo.insert!(%Secret{
                 name: name,
                 org_id: ctx.org_id,
                 project_id: ctx.project_id,
                 created_by: ctx.user_id,
                 updated_by: ctx.user_id,
                 content: content,
                 content_encrypted: encrypted,
                 used_by: ModelFactory.prepare_checkout(),
                 used_at: DateTime.truncate(ctx.now, :second)
               })}
        end
      end

      defp prepare_params(ctx) do
        {:ok,
         params:
           API.Secret.new(
             metadata:
               API.Secret.Metadata.new(
                 name: "dt.#{ctx.project_id}",
                 org_id: ctx.org_id,
                 project_id_or_name: ctx.project_id
               )
           ),
         raw_data:
           API.Secret.Data.new(
             env_vars: [
               API.Secret.EnvVar.new(
                 name: "ENV_VAR",
                 value: "value"
               )
             ],
             files: [
               API.Secret.File.new(
                 path: "/home/path",
                 content: "content"
               )
             ]
           )}
      end
    end
  end
end
