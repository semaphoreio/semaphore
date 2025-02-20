defmodule Guard.AvatarTest do
  use Guard.RepoCase, async: true

  setup do
    github_user1 = Ecto.UUID.generate()
    github_user2 = Ecto.UUID.generate()
    other_user = Ecto.UUID.generate()
    other_user2 = Ecto.UUID.generate()
    other_user3 = Ecto.UUID.generate()

    members = [
      %{
        email: "bar@example.org",
        display_name: "Katty Doe",
        user_id: github_user1,
        providers: [
          %{provider: "github", uid: "123"},
          %{provider: "bitbucket", uid: "134"}
        ]
      },
      %{
        email: "baz@example.org",
        display_name: "Katty Does",
        user_id: github_user2,
        provider: "github",
        uid: "1234"
      },
      %{
        email: "foo@example.org",
        display_name: "John Doe",
        user_id: other_user,
        providers: [%{provider: "bitbucket", uid: "123"}]
      },
      %{
        email: "",
        display_name: "John Doe",
        user_id: other_user2,
        provider: "bitbucket",
        uid: "123"
      },
      %{
        display_name: "Mikołaj Kutryj",
        login: "Mikołaj Kutryj",
        user_id: other_user3,
        provider: "bitbucket",
        uid: "01b41c8b-0410-4488-a813-e82b8803c846"
      }
    ]

    [
      members: members,
      github_user1: github_user1,
      github_user2: github_user2,
      other_user: other_user,
      other_user2: other_user2,
      other_user3: other_user3
    ]
  end

  describe "inject_avatar" do
    test "injects avatars", %{
      members: members,
      github_user1: github_user1,
      github_user2: github_user2,
      other_user: other_user,
      other_user2: other_user2,
      other_user3: other_user3
    } do
      {:ok, members} = Guard.Avatar.inject_avatar(members)

      assert extract_avatar(members, github_user1) ==
               "https://avatars.githubusercontent.com/u/123?v=4"

      assert extract_avatar(members, github_user2) ==
               "https://avatars.githubusercontent.com/u/1234?v=4"

      assert extract_avatar(members, other_user) ==
               "https://secure.gravatar.com/avatar/64f677e30cd713a9467794a26711e42d?d=https%3A%2F%2Fui-avatars.com%2Fapi%2FJohn%2BDoe%2F128%2F000000%2Fffffff%2F2%2F0.5%2Ftrue%2Ftrue%2Ffalse%2Fpng"

      assert extract_avatar(members, other_user2) ==
               "https://ui-avatars.com/api/John+Doe/128/000000/ffffff/2/0.5/true/true/false/png"

      assert extract_avatar(members, other_user3) ==
               "https://ui-avatars.com/api/Miko%C5%82aj+Kutryj/128/000000/ffffff/2/0.5/true/true/false/png"
    end
  end

  defp extract_avatar(members, user_id),
    do: Enum.find_value(members, fn m -> if m.user_id == user_id, do: m.avatar_url end)
end
