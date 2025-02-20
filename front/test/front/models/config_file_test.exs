defmodule Front.Models.ConfigFileTest do
  use ExUnit.Case
  alias Front.Models.ConfigFile

  describe ".construct_list" do
    test "it constructs a list of files from raw data" do
      data =
        InternalApi.Secrethub.Secret.Data.new(
          files: [
            InternalApi.Secrethub.Secret.File.new(
              path: "/var/",
              content: "123"
            ),
            InternalApi.Secrethub.Secret.File.new(
              path: "/tmp",
              content: "456"
            )
          ]
        )

      files = ConfigFile.construct_list(data)

      assert Enum.count(files) == 2

      first = List.first(files)
      assert first.path == "/var/"

      last = List.last(files)
      assert last.path == "/tmp"
    end
  end
end
