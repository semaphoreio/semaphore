defmodule Rbac.Okta.Saml.Esaml do
  @moduledoc """
  Esaml seems to be the most stable library for dealing with SAML related
  things in the erlang/elixir universe. Unfortunatly, it is an Erlang library
  so we can't use it directly, and first need to set up some local stubs
  based on the esaml.hrl header files.
  """

  require Record
  import Record, only: [defrecord: 2, extract: 2]

  @esaml_hrl "esaml/include/esaml.hrl"

  defrecord :esaml_org, extract(:esaml_org, from_lib: @esaml_hrl)
  defrecord :esaml_contact, extract(:esaml_contact, from_lib: @esaml_hrl)
  defrecord :esaml_sp_metadata, extract(:esaml_sp_metadata, from_lib: @esaml_hrl)
  defrecord :esaml_idp_metadata, extract(:esaml_idp_metadata, from_lib: @esaml_hrl)
  defrecord :esaml_authnreq, extract(:esaml_authnreq, from_lib: @esaml_hrl)
  defrecord :esaml_subject, extract(:esaml_subject, from_lib: @esaml_hrl)
  defrecord :esaml_assertion, extract(:esaml_assertion, from_lib: @esaml_hrl)
  defrecord :esaml_logoutreq, extract(:esaml_logoutreq, from_lib: @esaml_hrl)
  defrecord :esaml_logoutresp, extract(:esaml_logoutresp, from_lib: @esaml_hrl)
  defrecord :esaml_response, extract(:esaml_response, from_lib: @esaml_hrl)
  defrecord :esaml_sp, extract(:esaml_sp, from_lib: @esaml_hrl)
end
