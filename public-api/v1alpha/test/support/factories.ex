defmodule Support.Factories do
  alias InternalApi.Organization.Organization

  def internal_api_status_ok do
    %InternalApi.Status{
      code: Google.Rpc.Code.value(:OK),
      message: ""
    }
  end

  def status_ok do
    InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK))
  end

  def organizations do
    [
      Organization.new(
        org_id: "1",
        name: "RT1",
        org_username: "rt1",
        avatar_url: "avatar.com",
        created_at: Google.Protobuf.Timestamp.new(seconds: 1_522_495_543),
        open_source: false,
        owner_id: "1"
      ),
      Organization.new(
        org_id: "2",
        name: "RT2",
        org_username: "rt2",
        avatar_url: "avatar.com",
        created_at: Google.Protobuf.Timestamp.new(seconds: 1_522_495_543),
        open_source: false,
        owner_id: "2"
      ),
      Organization.new(
        org_id: "3",
        name: "RT3",
        org_username: "rt3",
        avatar_url: "avatar.com",
        created_at: Google.Protobuf.Timestamp.new(seconds: 1_522_495_543),
        open_source: false,
        owner_id: "3"
      ),
      Organization.new(
        org_id: "92be62c2-9cf4-4dad-b168-d6efa6aa5e21",
        name: "Semaphore",
        org_username: "semaphore",
        avatar_url: "avatar.com",
        created_at: Google.Protobuf.Timestamp.new(seconds: 1_522_495_543),
        open_source: false,
        owner_id: "4"
      )
    ]
  end

  def organization(params \\ []) do
    defaults = [
      name: "Rendered Text",
      org_username: "renderedtext",
      created_at: Google.Protobuf.Timestamp.new(seconds: 1_522_495_543),
      avatar_url: "https://gravatar.com/avatar/7c1f2250f5f193cd60d4bc3b569be862.png",
      org_id: "78114608-be8a-465a-b9cd-81970fb802c7",
      owner_id: "78114608-be8a-465a-b9cd-81970fb802c7",
      open_source: false
    ]

    defaults |> Keyword.merge(params) |> InternalApi.Organization.Organization.new()
  end

  def user(params \\ []) do
    defaults = [
      id: "78114608-be8a-465a-b9cd-81970fb802c5",
      username: "milica-nerlovic",
      name: "Milica",
      avatar_url: "https://gravatar.com/avatar/c716c3715a66612b070b6408b89c1190.png",
      github_uid: "githubuid",
      api_token: "skjelkejfde",
      github_login: "milica-nerlovic"
    ]

    defaults |> Keyword.merge(params) |> InternalApi.User.User.new()
  end
end
