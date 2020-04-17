defmodule Pdf.ExternalFontTest do
  use ExUnit.Case, asyn: true

  alias Pdf.ExternalFont
  alias Pdf.Font
  alias Pdf.Size
  alias Pdf.Export

  @font "Verdana"

  setup do
    %ExternalFont{} = font = ExternalFont.load("test/fonts/#{@font}.afm")
    %{font: font}
  end

  test "font metrics", %{font: font} do
    assert font.name == @font
  end

  test "font file", %{font: font} do
    {:ok, %{size: size}} = File.stat("test/fonts/#{@font}.pfb")
    assert byte_size(font.font_file) == size
  end

  describe "dictionary" do
    setup do
      font = ExternalFont.load("test/fonts/#{@font}.afm")
      dict = font.dictionary
      %{dict: dict, font: font}
    end

    test "entries", %{dict: dict} do
      assert length(Map.keys(dict.entries)) == 4
    end

    test "size", %{font: font} do
      result = Export.to_iolist(font) |> Enum.join()

      assert Size.size_of(font) == byte_size(result)
    end
  end

  test "widths", %{font: font} do
    assert 256 == length(font.widths)
  end

  test "width/2", %{font: font} do
    assert 684 == ExternalFont.width(font, "A")
  end

  describe "text_width/3" do
    test "It calculates the width of a line of text", %{font: font} do
      assert Font.text_width(font, "VA") == 1368
      assert Font.text_width(font, "VA", 10) == 13.68
      assert Font.text_width(font, "VA", kerning: true) == 1339
      assert Font.text_width(font, "VA", 10, kerning: true) == 13.39
    end
  end
end
