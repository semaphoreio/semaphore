defmodule Audit.StreamerTest do
  use ExUnit.Case, async: true

  alias Audit.Streamer

  @key_id "FAKE-KEY-ID-0000"

  describe "error_summary/1" do
    test "keeps status, code and message of an http error and drops the rest" do
      body = """
      <?xml version="1.0" encoding="UTF-8"?>
      <Error><Code>SignatureDoesNotMatch</Code><Message>The request signature does not match.</Message>
      <AWSAccessKeyId>#{@key_id}</AWSAccessKeyId>
      <StringToSign>AWS4-HMAC-SHA256 fake-string-to-sign</StringToSign>
      <CanonicalRequest>PUT /fake-canonical-request</CanonicalRequest></Error>
      """

      error =
        {:http_error, 403,
         %{body: body, headers: [{"x-amz-request-id", "fake-request-id"}], status_code: 403}}

      summary = Streamer.error_summary(error)

      assert summary ==
               ~s(http_error status=403 code="SignatureDoesNotMatch" message="The request signature does not match.")

      assert Streamer.error_summary({:error, error}) == summary
    end

    test "truncates long provider messages" do
      body = "<Error><Code>Oops</Code><Message>#{String.duplicate("a", 500)}</Message></Error>"

      summary = Streamer.error_summary({:http_error, 500, %{body: body}})

      assert summary =~ String.duplicate("a", 200)
      refute summary =~ String.duplicate("a", 201)
    end

    test "http error without a parsable body" do
      assert Streamer.error_summary({:http_error, 502, %{body: "bad gateway"}}) ==
               "http_error status=502"

      assert Streamer.error_summary({:http_error, 502, %{}}) == "http_error status=502"
    end

    test "transport errors and exceptions carry no payload" do
      assert Streamer.error_summary(%{reason: :nxdomain}) == "request_error reason=nxdomain"
      assert Streamer.error_summary(:timeout) == "timeout"

      assert Streamer.error_summary(%RuntimeError{message: "secret #{@key_id}"}) ==
               "exception RuntimeError"

      assert Streamer.error_summary("anything with #{@key_id}") == "unknown_error"
      assert Streamer.error_summary({"odd", @key_id}) == "unknown_error"
    end
  end
end
