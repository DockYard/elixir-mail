defmodule Mail.Encoders.BinaryTest do
  use ExUnit.Case, async: true

  test "encode handles empty strings" do
    assert Mail.Encoders.Binary.encode("") == ""
  end

  test "encodes all data as-is" do
    message = "hełło\0world\r\n"
    assert Mail.Encoders.Binary.encode(message) == message
  end

  test "decode handles empty strings" do
    assert Mail.Encoders.Binary.decode("") == ""
  end

  test "decode all data as-is" do
    message = "hełło\0world\r\n"
    assert Mail.Encoders.Binary.decode(message) == message
  end
end
