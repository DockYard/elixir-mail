defmodule Pdf.FontTest do
  use ExUnit.Case, async: true

  describe "text_width/3" do
    test "It calculates the width of a line of text" do
      font = Pdf.Font.Helvetica
      assert font.text_width("VA") == 1334
      assert font.text_width("VA", 10) == 13.34
      assert font.text_width("VA", kerning: true) == 1254
      assert font.text_width("VA", 10, kerning: true) == 12.54
    end
  end
end
