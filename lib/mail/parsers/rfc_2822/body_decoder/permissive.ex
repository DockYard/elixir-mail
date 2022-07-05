defmodule Mail.Parsers.RFC2822.BodyDecoder.Permissive do
  @behaviour Mail.Parsers.RFC2822.BodyDecoder

  @plain_encodings ["7bit", "8bit", "binary"]

  @impl true
  def decode(body, message) do
    transfer_encoding = content_transfer_encoding(message)

    # The problem with these encodings is that we are not sure if CRLF
    # are actually part of the body or they are there to split lines
    # in order to meet the line length limit of 998 characters.
    # For parts with `Content-Type: message/rfc822` we need to preserve
    # everything to be sure we can later parse them.
    if transfer_encoding in @plain_encodings and content_type(message) == "message/rfc822" do
      Mail.Encoder.decode(body, "binary")
    else
      body
      |> String.trim_trailing()
      |> Mail.Encoder.decode(transfer_encoding)
    end
  end

  @spec content_transfer_encoding(Mail.Message.t()) :: String.t()
  defp content_transfer_encoding(message) do
    Mail.Message.get_header(message, "content-transfer-encoding") || "binary"
  end

  @spec content_type(Mail.Message.t()) :: String.t() | nil
  defp content_type(message) do
    case Mail.Message.get_header(message, "content-type") do
      [content_type | _] -> content_type
      _ -> nil
    end
  end
end
