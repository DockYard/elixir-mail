defmodule Pdf.Encoding.WinAnsiTest do
  use ExUnit.Case, async: true

  alias Pdf.Encoding.WinAnsi

  test "from_name/1" do
    assert WinAnsi.from_name("space") == 32
    assert WinAnsi.from_name("hyphen") == 0x2D
    assert WinAnsi.from_name("eacute") == 233
  end

  test "encode/1" do
    assert WinAnsi.encode("haven’t") == <<"haven\x92t">>

    assert_raise ArgumentError, "Incompatible with WinAnsi encoding", fn ->
      WinAnsi.encode("smile 😀")
    end
  end

  test "encode/2" do
    assert WinAnsi.encode("haven’t", "?") == <<"haven\x92t">>

    assert WinAnsi.encode("smile 😀", "?") == "smile ?"
  end
end
