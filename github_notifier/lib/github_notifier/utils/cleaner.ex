# github is not supporting unicode characters above 0xffff in statuses
#
defmodule GithubNotifier.Utils.Cleaner do
  def clean(string) do
    string |> to_charlist |> Enum.filter(fn char -> 0xFFFF >= char end) |> to_string
  end
end
