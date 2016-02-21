defmodule Mail.Encoders.QuotedPrintable do
  @moduledoc """
  Encodes/decodes quoted-printable strings according to RFC 2045.

  See the following links for reference:
  - <https://tools.ietf.org/html/rfc2045#section-6.7>
  """

  @new_line "=\r\n"
  @max_length 76

  @doc """
  Encodes a string into a quoted-printable encoded string.
  ## Examples
      iex> Mail.Encoders.QuotedPrintable.encode("façade")
      "fa=C3=A7ade"
  """
  def encode(string), do: do_encode(string, "", 0)
  defp do_encode(<<>>, acc, _), do: acc
  defp do_encode(<<head, tail::binary>>, acc, line_length) do
    {encoding, line_length} = encode_char(head, line_length, String.length(tail))
    do_encode(tail, acc <> encoding, line_length)
  end

  # Encode ASCII characters in range 0x20..0x3C.
  defp encode_char(char, line_length, _) when char in ?!..?< do
    emit_raw_char(char, line_length)
  end

  # Encode ASCII characters in range 0x3E..0x7E.
  defp encode_char(char, line_length, _) when char in ?>..?~ do
    emit_raw_char(char, line_length)
  end

  # Encode ASCII tab and space characters.
  defp encode_char(char, line_length, remaining) when char in [?\t, ?\s] do
    if remaining > 0 do
      emit_raw_char(char, line_length)
    else
      emit_escaped_char(char, line_length, @max_length)
    end
  end

  # Encode all other characters.
  defp encode_char(char, line_length, _) do
    emit_escaped_char(char, line_length, @max_length - 1)
  end

  defp emit_escaped_char(char, line_length, maximum) do
    escaped = "=" <> Base.encode16(<<char>>)
    escaped_length = String.length(escaped)
    if line_length + escaped_length <= maximum do
      {escaped, line_length + escaped_length}
    else
      {@new_line <> escaped, escaped_length}
    end
  end

  defp emit_raw_char(char, line_length) do
    if line_length < @max_length - 1 do
      {<<char>>, line_length + 1}
    else
      {@new_line <> <<char>>, 1}
    end
  end

  @doc """
  Decodes a quoted-printable encoded string.
  ## Examples
      iex> Mail.Encoders.QuotedPrintable.decode("fa=C3=A7ade")
      "façade"
  """
  def decode(string), do: do_decode(string, "")
  defp do_decode(<<>>, acc), do: acc
  defp do_decode(<<head, tail::binary>>, acc) do
    {decoded, tail} = decode_char(head, tail)
    do_decode(tail, acc <> decoded)
  end

  defp decode_char(?=, <<char1, char2, tail::binary>>) do
    {decode_escaped_char(char1, char2), tail}
  end

  defp decode_char(char, tail) do
    {<<char>>, tail}
  end

  defp decode_escaped_char(?\r, ?\n), do: ""
  defp decode_escaped_char(char1, char2) do
    chars = <<char1>> <> <<char2>>
    case Base.decode16(chars, case: :mixed) do
      {:ok, decoded} -> decoded
      :error -> "=" <> chars
    end
  end
end
