defmodule Ppl.RequestReviser do
  @moduledoc """
  Updates user request.
  """

  alias Block.CodeRepo.Expand

  @definition_file_path ".semaphore/"
  @definition_file_name "semaphore.yml"

  def revise(request) do
    request
    |> defaults_for_definition_file_name_and_path
    |> handle_definition_file()
    |> normalize_definition_file_name_and_path
  end

  def defaults_for_definition_file_name_and_path(request) do
    request
    |> Map.update("working_dir", @definition_file_path, &(&1))
    |> Map.update("file_name", @definition_file_name, &(&1))
  end

  defp handle_definition_file(request) do
    Map.get(request, "definition_file", "")
    |> case  do
      "" ->
        request
      definition_file ->
        request
        |> Map.delete("definition_file")
        # Puthing everything in "file_name" and expecting function
        # "normalize_definition_file_name_and_path" to
        # separate "working_dir" and "file_name".
        |> Map.merge(%{"working_dir" => "", "file_name" => definition_file})
    end
  end

  defp normalize_definition_file_name_and_path(request) do
    full_name = Expand.full_name(request["working_dir"], request["file_name"])

    request
    |> Map.put("working_dir", Path.dirname(full_name))
    |> Map.put("file_name", Path.basename(full_name))
  end
end
