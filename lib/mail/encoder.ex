defmodule Mail.Encoder do
  @moduledoc """
  Primary encoding/decoding bottleneck for the library.

  Will delegate to the proper encoding/decoding functions based upon name
  """

  def encode(data, encoding) when is_binary(encoding),
    do: encode(data, String.to_atom(encoding))
  def encode(data, encoding) do
    case encoding do
      :base64 -> Mail.Encoders.Base64.encode(data)
      _ -> Mail.Encoders.Binary.encode(data)
    end
  end

  def decode(data, encoding) when is_binary(encoding),
    do: decode(data, String.to_atom(encoding))
  def decode(data, encoding) do
    case encoding do
      :base64 -> Mail.Encoders.Base64.decode(data)
      _ -> Mail.Encoders.Binary.decode(data)
    end
  end
end
