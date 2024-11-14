defmodule Mail.Encoders.EightBitTest do
  use ExUnit.Case, async: true

  test "encode handles empty strings" do
    assert Mail.Encoders.EightBit.encode("") == ""
  end

  test "encode wraps lines longer than 1000 characters" do
    message = String.duplicate("-", 2000)
    encoding = Mail.Encoders.EightBit.encode(message)
    assert binary_part(encoding, 998, 2) == "\r\n"
    assert binary_part(encoding, 1998, 2) == "\r\n"
    assert byte_size(encoding) == 2004
  end

  test "encode raises if any character is <NUL>" do
    assert_raise ArgumentError, fn ->
      Mail.Encoders.EightBit.encode("\0")
    end
  end

  test "decode handles empty strings" do
    assert Mail.Encoders.EightBit.decode("") == ""
  end

  test "decode preserves <CR><LF> pairs" do
    message = "This is a \r\ntest\r\n"
    assert Mail.Encoders.EightBit.decode(message) == "This is a \r\ntest\r\n"
  end

  test "decode removes crlf wrapping characters" do
    message = String.duplicate("-", 1000)
    encoded = Mail.Encoders.EightBit.encode(message)
    assert binary_part(encoded, 998, 2) == "\r\n"
    assert message == Mail.Encoders.EightBit.decode(encoded)
  end

  test "decode raises if any character is <NUL>" do
    assert_raise ArgumentError, fn ->
      Mail.Encoders.EightBit.decode("\0")
    end
  end
end
