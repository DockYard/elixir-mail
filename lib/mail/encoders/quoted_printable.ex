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

      Mail.Encoders.QuotedPrintable.encode("façade")
      "fa=C3=A7ade"
  """
  @spec encode(binary) :: binary
  @spec encode(binary, integer, binary, non_neg_integer) :: binary
  def encode(string, max_length \\ @max_length, acc \\ <<>>, line_length \\ 0)

  def encode(<<>>, _, acc, _), do: acc

  # Encode ASCII characters in range 0x20..0x3C.
  # Encode ASCII characters in range 0x3E..0x7E, except 0x3F (question mark)
  def encode(<<char, tail::binary>>, max_length, acc, line_length)
      when char in ?!..?< or char in ?@..?~ or char == ?> do
    if line_length < max_length - 1 do
      encode(tail, max_length, acc <> <<char>>, line_length + 1)
    else
      encode(tail, max_length, acc <> @new_line <> <<char>>, 1)
    end
  end

  # Encode ASCII tab and space characters.
  def encode(<<char, tail::binary>>, max_length, acc, line_length) when char in [?\t, ?\s] do
    # if remaining > 0 do
    if byte_size(tail) > 0 do
      if line_length < max_length - 1 do
        encode(tail, max_length, acc <> <<char>>, line_length + 1)
      else
        encode(tail, max_length, acc <> @new_line <> <<char>>, 1)
      end
    else
      escaped = "=" <> Base.encode16(<<char>>)
      line_length = line_length + byte_size(escaped)

      if line_length <= max_length do
        encode(tail, max_length, acc <> escaped, line_length)
      else
        encode(tail, max_length, acc <> @new_line <> escaped, byte_size(escaped))
      end
    end
  end

  # Encode all other characters.
  def encode(<<char, tail::binary>>, max_length, acc, line_length) do
    escaped = "=" <> Base.encode16(<<char>>)
    line_length = line_length + byte_size(escaped)

    if line_length < max_length do
      encode(tail, max_length, acc <> escaped, line_length)
    else
      encode(tail, max_length, acc <> @new_line <> escaped, byte_size(escaped))
    end
  end

  @doc """
  Decodes a quoted-printable encoded string.

  ## Examples

      Mail.QuotedPrintable.decode("fa=C3=A7ade")
      "façade"
  """
  @spec decode(binary) :: binary
  def decode(string, acc \\ [])

  def decode(<<>>, acc) do
    acc
    |> Enum.reverse()
    |> Enum.join()
  end

  def decode(<<?=, ?\r, ?\n, tail::binary>>, acc) do
    decode(tail, acc)
  end

  def decode(<<?=, chars::binary-size(2), tail::binary>>, acc) do
    case Base.decode16(chars, case: :mixed) do
      {:ok, decoded} -> decode(tail, [decoded | acc])
      :error -> decode(tail, [chars, "=" | acc])
    end
  end

  def decode(<<char::binary-size(1), tail::binary>>, acc) do
    decode(tail, [char | acc])
  end
end
