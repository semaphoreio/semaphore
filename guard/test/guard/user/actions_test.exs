defmodule Guard.User.ActionsTest do
  use Guard.RepoCase, async: true

  import Mock

  describe "#create" do
    test "with proper params it will create a user" do
      with_mock Guard.Events.UserCreated, publish: fn _, _ -> :ok end do
        user_params = %{
          email: "john@example.com",
          name: "John"
        }

        {:ok, user} = Guard.User.Actions.create(user_params)

        assert user.email == "john@example.com"
        assert user.name == "John"
      end
    end

    test "with repository provider" do
      with_mock Guard.Events.UserCreated, publish: fn _, _ -> :ok end do
        user_params = %{
          email: "john@example.com",
          name: "John",
          repository_providers: [
            %{
              type: InternalApi.User.RepositoryProvider.Type.value(:GITHUB),
              uid: "123",
              login: "foo"
            }
          ]
        }

        {:ok, user} = Guard.User.Actions.create(user_params)
        {:ok, rha} = Guard.FrontRepo.RepoHostAccount.get_for_github_user(user.id)

        assert user.email == "john@example.com"
        assert user.name == "John"
        assert rha.login == "foo"
      end
    end

    test "with invalid repository provider" do
      with_mock Guard.Events.UserCreated, publish: fn _, _ -> :ok end do
        user_params = %{
          email: "john@example.com",
          name: "John",
          repository_providers: [
            %{
              type: InternalApi.User.RepositoryProvider.Type.value(:GITHUB),
              uid: "",
              login: "foo"
            }
          ]
        }

        {:error, message} = Guard.User.Actions.create(user_params)
        assert [github_uid: _] = message
      end
    end

    test "with duplicate email it will return error" do
      with_mock Guard.Events.UserCreated, publish: fn _, _ -> :ok end do
        user_params = %{
          email: "john@example.com",
          name: "John"
        }

        {:ok, user} = Guard.User.Actions.create(user_params)

        assert user.email == "john@example.com"
        assert user.name == "John"

        {:error, message} = Guard.User.Actions.create(user_params)

        assert [email: _] = message
      end
    end
  end

  describe "#update" do
    test "with proper params it will update a user" do
      with_mock Guard.Events.UserCreated, publish: fn _, _ -> :ok end do
        user_params = %{
          email: "john@example.com",
          name: "John"
        }

        {:ok, user} = Guard.User.Actions.create(user_params)

        assert user.email == "john@example.com"
        assert user.name == "John"

        user_params = %{
          email: "john2@example.com"
        }

        {:ok, user} = Guard.User.Actions.update(user.id, user_params)

        assert user.email == "john2@example.com"
        assert user.name == "John"
      end
    end

    test "with duplicate email it will return error" do
      with_mock Guard.Events.UserCreated, publish: fn _, _ -> :ok end do
        user_params = %{
          email: "john@example.com",
          name: "John"
        }

        {:ok, user} = Guard.User.Actions.create(user_params)

        user_params = %{
          email: "john2@example.com",
          name: "John"
        }

        {:ok, _} = Guard.User.Actions.create(user_params)

        user_params = %{
          email: "john2@example.com"
        }

        {:error, message} = Guard.User.Actions.update(user.id, user_params)

        assert [email: _] = message
      end
    end
  end
end
