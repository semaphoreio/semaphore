defmodule Block.CodeRepo.Local do
  @moduledoc """
  Get file from local repo.

  For early development purposes repos will be located in local dir.
  Such repos are called local repos.
  """

  @doc ~S"""
      iex> Block.CodeRepo.Local.get_file("1_config_file_exists", ".semaphore/semaphore.yml")
      {:ok, "I'm here!\n"}
  """
  def get_file(repo_name, file_name, _opts \\ %{}) do
    repo_path = repo_path(repo_name)
    with  {:ok, _} <- repo_exists?(repo_path),
          ppl_definition_file = repo_file(repo_path, file_name),
          {:ok, _} <- ppl_definition_file_exists?(ppl_definition_file),
    do: File.read(ppl_definition_file)
  end

  defp repo_path(repo_name), do: "#{:code.priv_dir(:block)}/repos/#{repo_name}"

  def repo_exists?(repo), do: repo |> File.stat |> repo_exists_rh(repo)

  def repo_exists_rh(stat = {:ok, %{:type => :directory}}, _repo), do: stat
  def repo_exists_rh(stat, repo) do
    msg = "Repo '#{repo}' does not exist."
    error = "#{inspect stat}"
    {:error, {:malformed, {msg, error}}}
  end

  defp repo_file(repo_path, file_name), do: "#{repo_path}/#{file_name}"

  def ppl_definition_file_exists?(file), do:
    file |> File.stat |> definition_exists?(file)

  def definition_exists?(stat = {:ok, %{:type => :regular}}, _), do: {:ok, stat}
  def definition_exists?(stat, ppl_file) do
    msg = "File '#{ppl_file}' is not available"
    error = "#{inspect stat}"
    {:error, {:malformed, {msg, error}}}
  end
end
