defmodule Support.Okta.Saml.XML do
  @moduledoc """
  Erlang's xmerl seems to be the best XML tool in the ecosystem for
  building dynamic XML data. A close contender was SweetXML, but it
  is overloaded with weird macros.

  Now, to use records defined in Erlang, we need to include the
  header files and replicate their names in Elixir. The syntax is
  weird, but once you get a hang of it, it is super simple.
  """

  require Record
  import Record, only: [defrecord: 2, extract: 2]

  # The erlang headers files are stored in deps/xmerl directory.
  @hrl "xmerl/include/xmerl.hrl"

  defrecord :xmlNamespace, extract(:xmlNamespace, from_lib: @hrl)
  defrecord :xmlElement, extract(:xmlElement, from_lib: @hrl)
  defrecord :xmlText, extract(:xmlText, from_lib: @hrl)
  defrecord :xmlAttribute, extract(:xmlAttribute, from_lib: @hrl)

  #
  # Utility methods for simpler XML element creation.
  #
  # Most important features:
  # - makes sure that we always convert strings to charlist (remember erlang string != elixir string)
  # - makes sure that we always convert to atoms where necessary (ex. element name)
  #

  def attr(name, value) do
    xmlAttribute(name: String.to_atom(name), value: to_charlist(value))
  end

  def ns(name, value) do
    xmlNamespace(nodes: [{to_charlist(name), String.to_atom(value)}])
  end

  def el(opts) do
    name = opts[:name] || ""
    attributes = opts[:attributes] || []
    content = opts[:content] || []

    xmlElement(name: String.to_atom(name), attributes: attributes, content: content)
  end

  def text(val) do
    xmlText(value: to_charlist(val))
  end
end
