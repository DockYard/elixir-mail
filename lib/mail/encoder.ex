defmodule Mail.Encoder do
  def encode(string, encoding) do
    case encoding do
      "base64" -> Mail.Encoders.Base64.encode(string)
      _ -> Mail.Encoders.Identity.encode(string)
    end
  end

  def decode(string, encoding) do
    case encoding do
      "base64" -> Mail.Encoders.Base64.decode(string)
      _ -> Mail.Encoders.Identity.decode(string)
    end
  end
end
