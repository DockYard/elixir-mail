defmodule Mail.EncoderTest do
  use ExUnit.Case, async: true
  alias Mail.Encoder

  describe "encode/decode" do
    test "encodes a binary in 7bit" do
      # odd casing
      # nothing to do here really...
      assert "Hello,\nWorld" == Encoder.encode("Hello,\nWorld", "7BIT")
      assert "Hello,\nWorld" == Encoder.decode("Hello,\nWorld", "7Bit")
    end

    test "encodes a binary in 8bit" do
      # odd casing
      # nothing to do here really...
      assert "Hello,\nWorld" == Encoder.encode("Hello,\nWorld", "8BIT")
      assert "Hello,\nWorld" == Encoder.decode("Hello,\nWorld", "8Bit")
    end

    test "encodes a binary as base64" do
      # with odd casings
      assert "SGVsbG8sIFdvcmxk" == Encoder.encode("Hello, World", "BASE64")
      assert "Hello, World" == Encoder.decode("SGVsbG8sIFdvcmxk\r\n", "Base64")
    end

    test "encodes a binary in quoted-printable" do
      # odd casing
      assert "Hello,=0AWorld" == Encoder.encode("Hello,\nWorld", "Quoted-Printable")
      assert "Hello,\nWorld" == Encoder.decode("Hello,=0AWorld", "QUOTED-PRINTABLE")
    end

    test "... everything else" do
      assert "Hello,\nWorld" == Encoder.encode("Hello,\nWorld", "ASCII")
      assert "Hello,\nWorld" == Encoder.decode("Hello,\nWorld", "UTF-8")
      assert "Hello,\nWorld" == Encoder.decode("Hello,\nWorld", "binary")
    end
  end
end
