defmodule Audit.StreamerTest do
  use ExUnit.Case, async: true

  alias Audit.Streamer

  @key_id "FAKE-KEY-ID-0000"

  describe "error_summary/1" do
    test "keeps status and code of an http error and drops the rest" do
      body = """
      <?xml version="1.0" encoding="UTF-8"?>
      <Error><Code>SignatureDoesNotMatch</Code>
      <Message>Signature mismatch for key #{@key_id}</Message>
      <AWSAccessKeyId>#{@key_id}</AWSAccessKeyId>
      <StringToSign>AWS4-HMAC-SHA256 fake-string-to-sign</StringToSign>
      <CanonicalRequest>PUT /fake-canonical-request</CanonicalRequest></Error>
      """

      error =
        {:http_error, 403,
         %{body: body, headers: [{"x-amz-request-id", "fake-request-id"}], status_code: 403}}

      summary = Streamer.error_summary(error)

      assert summary == "http_error status=403 code=SignatureDoesNotMatch"
      assert Streamer.error_summary({:error, error}) == summary
    end

    test "omits a code that is not a plain identifier" do
      for code <- ["Bad code #{@key_id}", String.duplicate("a", 65), ""] do
        body = "<Error><Code>#{code}</Code></Error>"

        assert Streamer.error_summary({:http_error, 500, %{body: body}}) ==
                 "http_error status=500"
      end
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
