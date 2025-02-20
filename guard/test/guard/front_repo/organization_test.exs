defmodule Guard.FrontRepo.OrganizationTest do
  use Guard.RepoCase, async: true

  alias Guard.FrontRepo.Organization

  describe "changeset validations" do
    test "validates required fields" do
      changeset = Organization.changeset(%Organization{}, %{})

      assert %{
               name: ["Cannot be empty"],
               username: ["Cannot be empty"],
               creator_id: ["Cannot be empty"]
             } = changeset.errors |> Map.new(fn {key, {msg, _}} -> {key, [msg]} end)
    end

    test "validates name length" do
      changeset = Organization.changeset(%Organization{}, %{name: String.duplicate("a", 63)})
      assert {"Too long", _} = changeset.errors[:name]
    end

    test "validates username format" do
      invalid_usernames = [
        "-starts-with-dash",
        "contains spaces",
        "UPPERCASE",
        "sh"
      ]

      for username <- invalid_usernames do
        changeset = Organization.changeset(%Organization{}, %{username: username})

        assert {"Use min. 3 characters, only lowercase letters a-z, numbers 0-9 and dash, no spaces.",
                _} = changeset.errors[:username]
      end

      valid_usernames = [
        "valid-username",
        "123numeric",
        "alpha123",
        "with-dashes-123"
      ]

      for username <- valid_usernames do
        changeset = Organization.changeset(%Organization{}, %{username: username})
        refute Keyword.get(changeset.errors, :username)
      end
    end

    test "validates restricted usernames" do
      restricted_usernames = ["admin", "api", "www", "billing"]

      for username <- restricted_usernames do
        changeset = Organization.changeset(%Organization{}, %{username: username})
        assert {"Already taken", _} = changeset.errors[:username]
      end

      changeset = Organization.changeset(%Organization{}, %{username: "valid-unrestricted-name"})
      refute Keyword.get(changeset.errors, :username)
    end

    test "validates ip_allow_list format" do
      valid_ips = [
        "192.168.0.128",
        "192.168.0.128,192.168.128.128",
        "10.0.0.0/24",
        "172.16.0.0/16",
        "192.168.1.1,10.0.0.0/24",
        "192.168.0.128/24,192.72.0.0/16",
        ""
      ]

      for ip_list <- valid_ips do
        changeset =
          Organization.changeset(%Organization{}, %{
            name: "test",
            username: "test-org",
            box_limit: 8,
            creator_id: Ecto.UUID.generate(),
            ip_allow_list: ip_list
          })

        refute Keyword.get(changeset.errors, :ip_allow_list)
      end

      invalid_ips = [
        "invalid",
        "256.256.256.256",
        "999.999.999.999/99",
        "192.168.1.1/33",
        "192.168.1",
        "192.168.1.1,invalid"
      ]

      for ip_list <- invalid_ips do
        changeset =
          Organization.changeset(%Organization{}, %{
            name: "test",
            username: "test-org",
            box_limit: 8,
            creator_id: Ecto.UUID.generate(),
            ip_allow_list: ip_list
          })

        assert {"IP Allow List should be a comma-separated list of IPs or CIDRs", _} =
                 changeset.errors[:ip_allow_list]
      end
    end
  end
end
