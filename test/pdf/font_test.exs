defmodule Pdf.FontTest do
  use ExUnit.Case, async: true
  alias Pdf.Font

  describe "text_width/3" do
    test "It calculates the width of a line of text" do
      font = Pdf.Font.Helvetica
      assert Font.text_width(font, "VA") == 1334
      assert Font.text_width(font, "VA", 10) == 13.34
      assert Font.text_width(font, "VA", kerning: true) == 1254
      assert Font.text_width(font, "VA", 10, kerning: true) == 12.54

      assert Font.text_width(font, "VA😀", 10, kerning: true, encoding_replacement_character: "?") ==
               Font.text_width(font, "VA?", 10, kerning: true)
    end

    test "It calculates the width of a blank string" do
      font = Pdf.Font.Helvetica
      assert Font.text_width(font, "") == 0
      assert Font.text_width(font, "", 10) == 0
      assert Font.text_width(font, "", kerning: true) == 0
      assert Font.text_width(font, "", 10, kerning: true) == 0
    end
  end

  describe "lookup" do
    assert Pdf.Font.Helvetica == Pdf.Font.lookup("Helvetica")
    assert Pdf.Font.HelveticaBold == Pdf.Font.lookup("Helvetica", bold: true)
    assert Pdf.Font.HelveticaBoldOblique == Pdf.Font.lookup("Helvetica", bold: true, italic: true)
    assert Pdf.Font.HelveticaOblique == Pdf.Font.lookup("Helvetica", bold: false, italic: true)
  end
end
