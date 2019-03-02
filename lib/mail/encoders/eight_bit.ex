defmodule Mail.Encoders.EightBit do
  @moduledoc """
  Encodes/decodes 8-bit strings according to RFC 2045.

  See the following link for reference:
  - <https://tools.ietf.org/html/rfc2045#section-2.8>
  """

  @new_line "\r\n"
  @wrap_length 998

  @doc """
  Encodes a string into an 8-bit encoded string.

  Raises if any character is <NUL> "\0".
  """
  def encode(string), do: do_encode(string, "", 0)
  defp do_encode(<<>>, acc, _line_length), do: acc

  defp do_encode(<<head, tail::binary>>, acc, line_length) do
    {encoding, line_length} = emit_char(head, line_length)
    do_encode(tail, acc <> encoding, line_length)
  end

  defp emit_char(?\0, _line_length) do
    raise ArgumentError, message: "illegal NUL character"
  end

  defp emit_char(char, line_length) do
    if line_length < @wrap_length do
      {<<char>>, line_length + 1}
    else
      {@new_line <> <<char>>, 1}
    end
  end

  @doc """
  Decodes an 8-bit encoded string.
  """
  def decode(string), do: do_decode(string, "")
  defp do_decode(<<>>, acc), do: acc

  defp do_decode(<<head, tail::binary>>, acc) do
    {decoded, tail} = decode_char(head, tail)
    do_decode(tail, acc <> decoded)
  end

  defp decode_char(?\r, <<?\n, tail::binary>>), do: {"", tail}
  defp decode_char(char, <<tail::binary>>), do: {<<char>>, tail}
end
