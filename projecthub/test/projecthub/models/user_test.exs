defmodule Projecthub.Models.UserTest do
  use Projecthub.DataCase
  import Mock

  alias Projecthub.Models.User

  describe ".find" do
    test "it fetches the user with correct params" do
      user_response =
        InternalApi.User.DescribeResponse.new(
          status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          user_id: "12345678-1234-5678-1234-567812345678"
        )

      FunRegistry.set!(Support.FakeServices.UserService, :describe, fn req, _stream ->
        assert req.user_id == "12345678-1234-5678-1234-567812345678"

        user_response
      end)

      assert User.find("12345678-1234-5678-1234-567812345678")
    end
  end

  describe ".check_github_permissions" do
    test "rejects a CRLF-carrying login before making any GitHub call" do
      with_mock Tentacat, [], get: fn _path, _client -> flunk("Tentacat should not be called") end do
        repo = %{owner: "renderedtext", name: "projecthub"}

        assert User.check_github_permissions("x\r\nX-Injected: yes", repo, "token") ==
                 {:error, :invalid_github_path_segment}
      end
    end

    test "rejects an unsafe repo owner/name before making any GitHub call" do
      with_mock Tentacat, [], get: fn _path, _client -> flunk("Tentacat should not be called") end do
        repo = %{owner: "owner/../other", name: "projecthub"}

        assert User.check_github_permissions("someone", repo, "token") ==
                 {:error, :invalid_github_path_segment}
      end
    end

    test "still reaches GitHub with the expected path for legitimate identifiers" do
      repo = %{owner: "renderedtext", name: "projecthub"}

      with_mock Tentacat, [],
        get: fn path, _client ->
          assert path == "repos/renderedtext/projecthub/collaborators/someone/permission"
          {200, %{"permission" => "admin"}, %{}}
        end do
        assert User.check_github_permissions("someone", repo, "token") == {:ok, :admin}
      end
    end
  end
end
