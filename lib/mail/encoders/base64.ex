defmodule Mail.Encoders.Base64 do
  def encode(string),
    do: Base.encode64(string)

  def decode(string),
    do: Base.decode64!(string)
end
