defmodule Mail.Encoders.Base64Test do
  use ExUnit.Case, async: true

  test "parses data with line feeds" do
    base64_sample =
      "SGVsbG8gd29ybGQhIEhlbGxvIHdvcmxkISBIZWxsbyB3b3JsZCEgSGVsbG8g\r\nd29ybGQhIEhlbGxvIHdvcmxkISBIZWxsbyB3b3JsZCE=\r\n"

    decoded = Mail.Encoders.Base64.decode(base64_sample)

    assert decoded ==
             "Hello world! Hello world! Hello world! Hello world! Hello world! Hello world!"
  end

  test "encodes data with line feeds" do
    message =
      "Hello world! Hello world! Hello world! Hello world! Hello world! Hello world! Hello world! Hello world! Hello world!"

    encoded = Mail.Encoders.Base64.encode(message)

    assert encoded ==
             "SGVsbG8gd29ybGQhIEhlbGxvIHdvcmxkISBIZWxsbyB3b3JsZCEgSGVsbG8gd29ybGQhIEhlbGxv\r\nIHdvcmxkISBIZWxsbyB3b3JsZCEgSGVsbG8gd29ybGQhIEhlbGxvIHdvcmxkISBIZWxsbyB3b3Js\r\nZCE=\r\n"
  end
end
