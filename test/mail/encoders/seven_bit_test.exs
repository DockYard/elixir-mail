defmodule Mail.Encoders.SevenBitTest do
  use ExUnit.Case, async: true

  test "encode handles empty strings" do
    assert Mail.Encoders.SevenBit.encode("") == ""
  end

  test "encode wraps lines longer than 1000 characters" do
    message = String.duplicate("-", 2000)
    encoding = Mail.Encoders.SevenBit.encode(message)
    assert binary_part(encoding, 998, 2) == "\r\n"
    assert binary_part(encoding, 1998, 2) == "\r\n"
    assert byte_size(encoding) == 2004
  end

  test "encode raises if any character isn't 7-bit ASCII" do
    assert_raise ArgumentError, fn ->
      Mail.Encoders.SevenBit.encode("hełło")
    end
  end

  test "encode raises if any character is <NUL>" do
    assert_raise ArgumentError, fn ->
      Mail.Encoders.SevenBit.encode("\0")
    end
  end

  test "decode handles empty strings" do
    assert Mail.Encoders.SevenBit.decode("") == ""
  end

  test "decode handles <CR><LF> pairs" do
    message = "This is a \r\ntest\r\n"
    assert Mail.Encoders.SevenBit.decode(message) == "This is a \ntest\n"
  end
end
