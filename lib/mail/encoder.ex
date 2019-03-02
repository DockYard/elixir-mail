defmodule Mail.Encoder do
  @moduledoc """
  Primary encoding/decoding bottleneck for the library.

  Will delegate to the proper encoding/decoding functions based upon name
  """

  @spec encoder_for(encoding :: String.t() | atom) :: atom
  def encoder_for(encoding) when is_atom(encoding) do
    encoding
    |> normalize()
    |> encoder_for()
  end

  def encoder_for(encoding) when is_binary(encoding) do
    case encoding |> String.trim() |> String.downcase() do
      "7bit" -> Mail.Encoders.SevenBit
      "8bit" -> Mail.Encoders.EightBit
      "base64" -> Mail.Encoders.Base64
      "quoted-printable" -> Mail.Encoders.QuotedPrintable
      _ -> Mail.Encoders.Binary
    end
  end

  @spec encode(data :: binary, encoding :: String.t()) :: binary
  def encode(data, encoding), do: encoder_for(encoding).encode(data)

  @spec decode(data :: binary, encoding :: String.t()) :: binary
  def decode(data, encoding), do: encoder_for(encoding).decode(data)

  defp normalize(:quoted_printable), do: normalize(:"quoted-printable")
  defp normalize(encoding) when is_atom(encoding), do: Atom.to_string(encoding)
end
