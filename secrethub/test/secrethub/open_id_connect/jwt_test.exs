defmodule Secrethub.OpenIDConnect.JWTTest do
  use Secrethub.DataCase

  alias Secrethub.OpenIDConnect.JWT
  alias Support.FakeServices

  defp base_req(extra \\ %{}) do
    org_id = Ecto.UUID.generate()
    project_id = Ecto.UUID.generate()
    repo = "web"
    ref_type = "branch"
    git_ref = "refs/heads/main"

    %{
      org_id: org_id,
      org_username: "testera",
      project_id: project_id,
      project_name: "my-project",
      workflow_id: Ecto.UUID.generate(),
      pipeline_id: Ecto.UUID.generate(),
      job_id: Ecto.UUID.generate(),
      repository_name: repo,
      git_tag: "",
      git_ref: git_ref,
      git_ref_type: ref_type,
      git_branch_name: "main",
      git_pull_request_number: "",
      git_pull_request_branch: "",
      job_type: "pipeline_job",
      repo_slug: "renderedtext/#{repo}",
      triggerer: "h:f,i:f",
      subject:
        "org:testera:project:#{project_id}:repo:#{repo}:ref_type:#{ref_type}:ref:#{git_ref}",
      user_id: Ecto.UUID.generate(),
      expires_in: 3600
    }
    |> Map.merge(extra)
  end

  describe "generate_and_sign/1 audience handling" do
    setup do
      FakeServices.enable_features([])
      :ok
    end

    test "defaults to org URL when audience is absent" do
      req = base_req()
      domain = Application.fetch_env!(:secrethub, :domain)

      assert {:ok, token} = JWT.generate_and_sign(req)
      assert {true, jwt, _} = JWT.verify(token)

      assert Map.get(jwt.fields, "aud") == "https://#{req.org_username}.#{domain}"
    end

    test "defaults to org URL when audience is an empty list" do
      req = base_req(%{audience: []})
      domain = Application.fetch_env!(:secrethub, :domain)

      assert {:ok, token} = JWT.generate_and_sign(req)
      assert {true, jwt, _} = JWT.verify(token)

      assert Map.get(jwt.fields, "aud") == "https://#{req.org_username}.#{domain}"
    end

    test "uses single string when audience is a single-element list (RFC 7519 convention)" do
      req = base_req(%{audience: ["pypi"]})

      assert {:ok, token} = JWT.generate_and_sign(req)
      assert {true, jwt, _} = JWT.verify(token)

      assert Map.get(jwt.fields, "aud") == "pypi"
    end

    test "uses JSON array when audience is a multi-element list" do
      req = base_req(%{audience: ["pypi", "https://other.example"]})

      assert {:ok, token} = JWT.generate_and_sign(req)
      assert {true, jwt, _} = JWT.verify(token)

      assert Map.get(jwt.fields, "aud") == ["pypi", "https://other.example"]
    end
  end
end
