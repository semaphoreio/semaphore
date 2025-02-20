defmodule Front.ArtifacthubResource do
  @doc """
  Functions in this module support communication with Artifacthub.

  `root_path?` - used to check if a specific path, requested by user in the UI,
  is main directory for the specific resource on the Artifacthub.
  Furthermore, based on its value. We need this to distinguish non-existing path
  artifact path from empty root path. In these two cases
  we get the same response from the Artifacthub.

  `get_name` - used to parse Artifacthub response.

  `get_relative_path` - used to parse Artifact response. We need relative path
  for supporting Artifact folder browsing in the UI.
  """

  def get_relative_path(full_path, source_kind, source_id) do
    remove_prefix(source_kind, source_id, full_path)
    |> String.trim("/")
  end

  def get_name(artifact_item, source_kind, id) do
    remove_prefix(source_kind, id, artifact_item.name)
    |> String.trim()
    |> String.split("/", trim: true)
    |> Enum.at(-1)
  end

  def root_path?(kind, id, path),
    do: path == dir_path(kind, id)

  def request_path(source_kind, id, relative_path) do
    dir_path(source_kind, id) <> relative_path
  end

  defp dir_path(kind, id) do
    "artifacts/#{kind}/#{id}/"
  end

  defp remove_prefix(kind, id, path) do
    String.replace_prefix(path, dir_path(kind, id), "")
  end
end
