defmodule Secrethub.OpenIDConnect.JWT do
  defmodule Token do
    use Joken.Config, default_key: :rs256
  end

  @claims [
    # Unique identifier; can be used to prevent the JWT from being replayed
    "jti",
    # Subject of the JWT
    "sub",
    # Compact subject limited to 127 chars (org:project_id:repo:ref_type:ref)
    "sub127",
    # Recipient for which the JWT is intended
    "aud",
    # Issuer of the JWT
    "iss",
    # Time after which the JWT expires
    "exp",
    # Time before which the JWT must not be accepted for processing
    "nbf",
    # Time at which the JWT was issued; can be used to determine age of the JWT
    "iat",
    # organization ID
    "org_id",
    # project  ID
    "prj_id",
    # workflow ID
    "wf_id",
    # pipeline ID
    "ppl_id",
    # job      ID
    "job_id",
    # repository name
    "repo",
    # the user ID who triggered the promotion, or NULL
    "actor",
    # the git tag that triggered the pipeline
    "tag",
    # the git reference that triggered the pipeline
    "ref",
    # the git ref type that triggered the pipeline
    "ref_type",
    # the branch name
    "branch",
    # the pull-request number that triggered the job
    "pr",
    # job type - "pipeline_job" or "debug_job" or "debug_project_job"
    "job_type",
    # the branch name which pull request originated from
    "pr_branch",
    # the repository slug - owner/repo, ie. semaphoreio/semaphore
    "repo_slug",
    # the triggerer - details about how workflow and pipeline were triggered
    # format "<wf_triggerer>:<wf_rerun>-<ppl_triggerer>:<ppl_rerun>"
    "trg"
  ]

  @aws_tags_claim "https://aws.amazon.com/tags"
  @max_subject_length 127
  @truncate_rules %{
    org: 25,
    project_id: 36,
    repo: 25,
    ref_type: 2,
    ref: 35
  }

  @algo "RS256"

  def claims(org_id) do
    if FeatureProvider.feature_enabled?(:open_id_connect_aws_tags, param: org_id) do
      # This is helpful when using the OIDC token to create a temporary AWS session.
      # See: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_session-tags.html#id_session-tags_adding-assume-role-idp
      @claims ++
        [
          @aws_tags_claim
        ]
    else
      @claims
    end
  end

  def algo, do: @algo

  def generate_and_sign(req = %{expires_in: expire_in}) do
    key = active_key()
    headers = %{"kid" => key.id}
    {:ok, claims} = build_oidc_claims(req)
    signer = Joken.Signer.create(@algo, key.key, headers)

    claims =
      claims
      |> Map.put("exp", Joken.current_time() + expire_in)

    {:ok, token, _claims} = __MODULE__.Token.generate_and_sign(claims, signer)

    {:ok, token}
  end

  def verify(token) do
    JOSE.JWT.verify_strict(active_key().key, [@algo], token)
  end

  defp active_key do
    Secrethub.OpenIDConnect.KeyManager.active_key(:openid_keys)
  end

  defp build_oidc_claims(req) do
    domain = Application.fetch_env!(:secrethub, :domain)

    common_claims = %{
      "org" => req.org_username,
      "org_id" => req.org_id,
      "prj" => req.project_name,
      "prj_id" => req.project_id,
      "wf_id" => req.workflow_id,
      "ppl_id" => req.pipeline_id,
      "job_id" => req.job_id,
      "repo" => req.repository_name,
      "actor" => req.user_id,
      "tag" => req.git_tag,
      "ref" => req.git_ref,
      "ref_type" => req.git_ref_type,
      "branch" => req.git_branch_name,
      "pr" => req.git_pull_request_number,
      "sub" => req.subject,
      "sub127" => build_subject_127(req),
      "iss" => "https://#{req.org_username}.#{domain}",
      "aud" => "https://#{req.org_username}.#{domain}",
      "job_type" => req.job_type,
      "pr_branch" => req.git_pull_request_branch,
      "repo_slug" => req.repo_slug,
      "trg" => req.triggerer
    }

    claims =
      if FeatureProvider.feature_enabled?(:open_id_connect_aws_tags, param: req.org_id) do
        common_claims
        |> Map.put(@aws_tags_claim, %{
          "principal_tags" => %{
            "prj_id" => [req.project_id],
            "repo" => [req.repository_name],
            "branch" => [req.git_branch_name],
            "ref_type" => [req.git_ref_type],
            "job_type" => [req.job_type],
            "pr_branch" => [req.git_pull_request_branch],
            "repo_slug" => [req.repo_slug],
            "trg" => [req.triggerer]
          },
          "transitive_tag_keys" => [
            "prj_id",
            "repo",
            "branch",
            "ref_type",
            "job_type",
            "pr_branch",
            "repo_slug",
            "trg"
          ]
        })
      else
        common_claims
      end

    Secrethub.OpenIDConnect.JWTFilter.filter_claims(claims, req.org_id, req.project_id)
  end

  defp build_subject_127(req) do
    org =
      req.org_username
      |> sanitize()
      |> cap(:org)

    project =
      req.project_id
      |> sanitize()
      |> cap(:project_id)

    repo =
      req.repository_name
      |> sanitize()
      |> cap(:repo)

    ref_type =
      req.git_ref_type
      |> sanitize()
      |> short_ref_type()
      |> cap(:ref_type)

    ref =
      req.git_ref
      |> sanitize()
      |> trim_refs_prefix()
      |> cap(:ref)

    [org, project, repo, ref_type, ref]
    |> Enum.join(":")
    |> String.slice(0, @max_subject_length)
  end

  defp sanitize(nil), do: ""

  defp sanitize(value) when is_binary(value) do
    String.replace(value, ":", "")
  end

  defp sanitize(value) do
    value
    |> to_string()
    |> sanitize()
  end

  defp trim_refs_prefix("refs/" <> rest), do: rest
  defp trim_refs_prefix(value), do: value

  defp cap(value, key) do
    limit = Map.fetch!(@truncate_rules, key)
    String.slice(value, 0, limit) || ""
  end

  defp short_ref_type("branch"), do: "br"
  defp short_ref_type("tag"), do: "tg"
  defp short_ref_type("pull_request"), do: "pr"
  defp short_ref_type("pull-request"), do: "pr"

  defp short_ref_type(value) when is_binary(value) and byte_size(value) > 2,
    do: String.slice(value, 0, 2)

  defp short_ref_type(value), do: value
end
