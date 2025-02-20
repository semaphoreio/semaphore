defmodule Front.Models.ConfigFile do
  defstruct [:path, :content, :md5]

  def construct_list(nil), do: []

  def construct_list(data) do
    data.files
    |> Enum.map(fn file ->
      %__MODULE__{
        path: file.path,
        content: file.content,
        md5: content_md5(file.content)
      }
    end)
  end

  def serialize_for_frontend(file) do
    %{path: file.path, md5: file.md5}
  end

  defp content_md5(content) do
    :erlang.md5(content)
    |> Base.encode16(case: :lower)
  end
end
