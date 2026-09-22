defmodule GithubNotifier.Utils.Level do
  def level(project, pipeline) do
    case project.status do
      nil ->
        []

      status ->
        status["pipeline_files"]
        |> Enum.filter(fn file -> file["path"] == pipeline.yaml_file_path end)
        |> Enum.map(fn %{"level" => level} ->
          level |> to_string() |> String.downcase()
        end)
        |> Enum.uniq()
        |> Enum.sort()
    end
  end
end
