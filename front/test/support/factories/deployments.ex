defmodule Support.Factories.Deployments do
  def prepare_params do
    %{
      "name" => "Production",
      "description" => "Production environment",
      "url" => "https://production.rtx.com",
      "bookmark_parameter1" => "parameter1",
      "bookmark_parameter2" => "parameter2",
      "bookmark_parameter3" => "parameter3",
      "unique_token" => UUID.uuid4(),
      "branch_mode" => "whitelisted",
      "branches" =>
        wrap_object_items([
          %{"match_mode" => "1", "pattern" => "master"},
          %{"match_mode" => "2", "pattern" => "feature/*"}
        ]),
      "env_vars" =>
        wrap_env_vars([
          %{"name" => "EV1", "value" => "VALUE_1"},
          %{"name" => "EV2", "value" => "VALUE_2"}
        ]),
      "files" =>
        wrap_files([
          %{"path" => "F1", "content" => "CONTENT_1"},
          %{"path" => "F2", "content" => "CONTENT_2"}
        ]),
      "user_access" => "some",
      "roles" => [UUID.uuid4(), UUID.uuid4()],
      "members" => [UUID.uuid4(), UUID.uuid4()],
      "auto_promotions" => false,
      "pr_mode" => "all",
      "tag_mode" => "whitelisted",
      "tags" =>
        wrap_object_items([
          %{"match_mode" => "1", "pattern" => "v1.0.0"},
          %{"match_mode" => "2", "pattern" => "release/*"}
        ])
    }
  end

  def wrap_env_vars(env_vars) do
    env_vars
    |> Enum.map(&Map.put(&1, "id", &1["name"]))
    |> Enum.map(&wrap_creds(&1, ["id", "md5"]))
    |> Enum.with_index()
    |> Enum.into(%{}, fn {var, i} -> {to_string(i), var} end)
  end

  def wrap_files(files) do
    files
    |> Enum.map(&Map.put(&1, "id", &1["path"]))
    |> Enum.map(&wrap_creds(&1, ["id", "md5", "upload"]))
    |> Enum.with_index()
    |> Enum.into(%{}, fn {file, i} -> {to_string(i), file} end)
  end

  defp wrap_creds(item, defaults) do
    default_fields = Enum.into(defaults, %{}, &{&1, ""})
    Map.merge(default_fields, item)
  end

  def wrap_object_items(items) do
    items
    |> Enum.with_index()
    |> Enum.into(%{}, fn {item, i} -> {to_string(i), item} end)
  end
end
