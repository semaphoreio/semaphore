defmodule Guard.Invitees.LoginSegment do
  @moduledoc """
  Guards a GitHub/GitLab login before `Guard.Invitees` interpolates it into
  an outbound HTTP request.

  `Guard.Invitees.resource/2` builds two requests from a caller-supplied
  login with plain string interpolation and no encoding of any kind:

    * GitHub: `"https://api.github.com/users/\#{login}"` (login in the URL path)
    * GitLab: `"https://gitlab.com/api/v4/users?username=\#{login}"` (login in the query string)

  Both strings go straight through `HTTPoison.get/2` to hackney with no
  options. hackney's own fix for CRLF/request-splitting in its
  query-parameter construction (GHSA-j9wq-vxxc-94wf) ships only in the 4.x
  line, which guard cannot reach (httpoison pins `hackney ~> 1.17`, see
  `.mix-audit.txt`). On the hackney version guard actually runs, a login
  containing `\r\n` reaches hackney's query-building code unescaped through
  the GitLab call above, so that advisory is genuinely reachable here. This
  module is the real mitigation for it, not decoration.

  Rather than denylist the characters known to be dangerous, this module
  allowlists the only characters GitHub and GitLab usernames can contain: ASCII
  letters, digits, `.`, `_`, and `-`. A denylist has to anticipate every
  delimiter an attacker might reach for; anything it forgets (`&`, `=`, `;`,
  `@`, `%`, ...) can smuggle a second query parameter into the GitLab
  `?username=` request and diverge the resolved uid from the stored login. The
  allowlist rejects all of those by construction, and with them any character
  that could split a request line, inject a header, or redirect the request to
  a different path or endpoint, regardless of which hackney version ends up
  handling it.

  The anchors are `\\A`/`\\z` (absolute string start/end), not `^`/`$`: under
  PCRE `$` also matches immediately before a trailing newline, so `^...$` would
  accept `"radwo\\n"` and let a bare trailing LF through. `\\z` closes that.
  """

  @allowed ~r/\A[A-Za-z0-9._-]+\z/

  @doc """
  `{:ok, login}` if `login` consists only of characters valid in a GitHub or
  GitLab username (ASCII letters, digits, `.`, `_`, `-`) and is therefore safe
  to interpolate into the GitHub path or GitLab query built by
  `Guard.Invitees`, `{:error, :invalid_login_segment}` otherwise (empty values,
  non-strings, or any character outside that set).
  """
  @spec validate(term()) :: {:ok, String.t()} | {:error, :invalid_login_segment}
  def validate(login) when is_binary(login) do
    if login != "" and Regex.match?(@allowed, login) do
      {:ok, login}
    else
      {:error, :invalid_login_segment}
    end
  end

  def validate(_login), do: {:error, :invalid_login_segment}
end
