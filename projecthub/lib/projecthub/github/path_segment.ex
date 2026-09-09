defmodule Projecthub.Github.PathSegment do
  @moduledoc """
  Guards values before they are interpolated into a GitHub API URL path
  segment and handed to Tentacat.

  Tentacat builds request paths with raw string interpolation (e.g.
  `"repos/\#{owner}/\#{repo}/keys/\#{key_id}"` in
  `Tentacat.Repositories.DeployKeys`) and passes the resulting string
  straight through HTTPoison to hackney with no percent-encoding of its
  own. hackney itself does not sanitize path segments either: a value
  containing CR/LF can split the outbound request line or hijack a
  cookie-building helper (GHSA-j9wq-vxxc-94wf, GHSA-mp55-p8c9-rfw2), and
  separate hackney host/URL-parsing advisories (GHSA-pj7v-xfvx-wmjq,
  GHSA-gp9c-pm5m-5cxr) mean nothing downstream can be trusted to catch a
  hostile value either. None of that is projecthub's to fix inside
  hackney (the 4.x rewrite that carries the actual patches is blocked
  fleet-wide by httpoison's `~> 1.17` requirement, see `.mix-audit.txt`),
  so this module is the defense-in-depth guard for projecthub's own
  Tentacat call sites: `Projecthub.Models.User.check_github_permissions/3`
  and the GitHub-facing functions in `Projecthub.Models.DeployKey`.

  A value that never contains a control character (including space),
  `/`, `?`, or `#` can't be used to inject a header, split a request, or
  redirect it to a different path or endpoint in the first place,
  regardless of which hackney version ends up handling it.
  """

  @unsafe_chars ~r/[\x00-\x20\x7F\/\?\#]/

  @doc """
  `{:ok, value}` if `value` is safe to interpolate into a GitHub API URL
  path segment, `{:error, :invalid_github_path_segment}` otherwise (empty
  values, non-strings, control characters/space, or path/query/fragment
  delimiters).

  Every call site that guards a Tentacat call with this function must
  surface this same `{:error, :invalid_github_path_segment}` shape on
  rejection, so callers can pattern-match on one error regardless of
  which guarded function they called.
  """
  @spec validate(term()) :: {:ok, String.t()} | {:error, :invalid_github_path_segment}
  def validate(value) when is_binary(value) do
    if value == "" or Regex.match?(@unsafe_chars, value) do
      {:error, :invalid_github_path_segment}
    else
      {:ok, value}
    end
  end

  def validate(_value), do: {:error, :invalid_github_path_segment}
end
