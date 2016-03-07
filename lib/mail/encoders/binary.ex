defmodule Mail.Encoders.Binary do
  @moduledoc """
  Encodes/decodes binary strings according to RFC 2045.

  See the following link for reference:
  - <https://tools.ietf.org/html/rfc2045#section-2.9>
  """

  @doc """
  Encodes a string into a binary encoded string.
  """
  def encode(string), do: string

  @doc """
  Decodes a binary encoded string.
  """
  def decode(string), do: string
end
