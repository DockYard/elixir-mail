defmodule Mail.Encoders.Base64 do
  @moduledoc """
  Encodes/decodes base64 strings according to RFC 2045 which requires line
  lengths of less than 76 characters and illegal characters to be removed
  during parsing.

  See the following links for reference:
  - <https://www.ietf.org/rfc/rfc2045.txt>
  - <http://stackoverflow.com/questions/25710599/content-transfer-encoding-7bit-or-8-bit>
  - <http://stackoverflow.com/questions/13301708/base64-encode-length-parameter>
  """

  def encode(string),
    do:
      string
      |> Base.encode64()
      |> add_line_breaks()
      |> List.flatten()
      |> Enum.join()

  def decode(string),
    do: :base64.mime_decode(string)

  defp add_line_breaks(<<head::binary-size(76), tail::binary>>),
    do: [head, "\r\n" | add_line_breaks(tail)]

  defp add_line_breaks(tail), do: [tail, "\r\n"]
end
