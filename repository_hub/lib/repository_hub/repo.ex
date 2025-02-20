defmodule RepositoryHub.Repo do
  use Ecto.Repo,
    otp_app: :repository_hub,
    adapter: Ecto.Adapters.Postgres

  use Scrivener, page_size: 50, max_page_size: 200

  defmacro __using__(_) do
    quote do
      use Ecto.Schema
      @primary_key {:id, :binary_id, autogenerate: true}
      @foreign_key_type :binary_id
    end
  end
end
