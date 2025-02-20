defmodule Block.CodeRepo.Expand do
  @moduledoc """
  Join path and file and normalize full path
  """

  # If file name starts with "/" it is absolute path => disregard working dir
  def full_name(_working_dir, file_name = "/" <> _), do: String.trim(file_name)
  def full_name(working_dir, file_name) do
    file_name = String.trim(file_name)
    working_dir |> String.trim() |> Path.join(file_name) |> normalize_path()
  end

  defp normalize_path(path),
    do: path |> Path.expand() |> Path.relative_to_cwd()

end
