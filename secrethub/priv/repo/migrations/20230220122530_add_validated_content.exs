defmodule Secrethub.Repo.Migrations.AddValidatedContent do
  use Ecto.Migration
  import Ecto.Query

  def down do
    alter table(:secrets) do
      remove :content_validated
    end
  end

  def up do
    alter table(:secrets) do
      add :content_validated, :map
    end

    flush()

    "secrets"
    |> select([s], %{id: s.id, content: s.content})
    |> Secrethub.Repo.stream()
    |> Stream.map(&copy_content_to_content_validated/1)
    |> Stream.run()
  end


  defp copy_content_to_content_validated(%{content: content} = row) do
    content_validated =
      content
      |> Map.get("data")
      |> Map.take(["files", "env_vars"])

    "secrets"
    |> where([s], s.id == ^row.id)
    |> update([s], set: [content_validated: ^content_validated])
    |> Secrethub.Repo.update_all([])
  end
end
