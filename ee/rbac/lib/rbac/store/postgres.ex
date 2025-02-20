defmodule Rbac.Store.Postgres do
  @behaviour Rbac.Store
  import Ecto.Query

  @opts [timeout: 15_000]

  def get(store_name, key) do
    ecto_module = get_ecto_module_from_store_name(store_name)

    value =
      ecto_module
      |> where([key_value], key_value.key == ^key)
      |> select([key_value], key_value.value)
      |> Rbac.Repo.one()

    {:ok, value}
  end

  def put(store_name, key, value) do
    ecto_module = get_ecto_module_from_store_name(store_name)

    struct(ecto_module, key: key, value: value)
    |> Rbac.Repo.insert(on_conflict: {:replace, [:updated_at, :value]}, conflict_target: :key)
    |> case do
      {:ok, _} ->
        {:ok, 1}

      e ->
        e
    end
  end

  def put_batch(store_name, keys, values, opts \\ []) do
    ecto_module = get_ecto_module_from_store_name(store_name)
    opts = @opts |> Keyword.merge(opts ++ [on_conflict: :replace_all, conflict_target: :key])

    key_value_pairs =
      Enum.zip(keys, values) |> Enum.map(fn {key, value} -> %{key: key, value: value} end)

    {no_of_inserts, _} = Rbac.Repo.insert_all(ecto_module, key_value_pairs, opts)

    {:ok, no_of_inserts}
  end

  def delete(store_name, key) when not is_list(key) do
    delete(store_name, [key])
  end

  def delete(store_name, keys) when is_list(keys) do
    ecto_module = get_ecto_module_from_store_name(store_name)

    {no_of_deletions, nil} =
      ecto_module |> where([kv], kv.key in ^keys) |> Rbac.Repo.delete_all()

    {:ok, no_of_deletions}
  end

  def clear(store_name) do
    ecto_module = get_ecto_module_from_store_name(store_name)
    no_of_entities = ecto_module |> Rbac.Repo.aggregate(:count, :key)
    ecto_module |> Rbac.Repo.delete_all()
    {:ok, no_of_entities}
  end

  defp get_ecto_module_from_store_name(store_name) do
    String.to_existing_atom("Elixir.Rbac.Repo." <> store_name)
  end
end
