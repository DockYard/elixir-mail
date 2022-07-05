defmodule Mail.Parsers.RFC2822.BodyDecoder.Strict do
  @behaviour Mail.Parsers.RFC2822.BodyDecoder

  @impl true
  def decode(body, message) do
    transfer_encoding = Mail.Message.get_header(message, "content-transfer-encoding")

    body
    |> String.trim_trailing()
    |> Mail.Encoder.decode(transfer_encoding)
  end
end
