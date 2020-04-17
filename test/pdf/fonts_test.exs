defmodule Pdf.FontsTest do
  use ExUnit.Case

  alias Pdf.Document
  alias Pdf.Fonts
  alias Pdf.ExternalFont

  test "looking up an internal font by name" do
    document = Document.new()

    assert %Fonts.FontReference{module: Pdf.Font.Helvetica} =
             Fonts.get_font(document.fonts, "Helvetica", [])
  end

  test "looking up an internal font by font, bold" do
    document = Document.new()

    assert %Fonts.FontReference{module: Pdf.Font.HelveticaBold} =
             Fonts.get_font(document.fonts, Pdf.Font.Helvetica, bold: true)
  end

  test "looking up an internal font by name, bold" do
    document = Document.new()

    assert %Fonts.FontReference{module: Pdf.Font.HelveticaBold} =
             Fonts.get_font(document.fonts, "Helvetica", bold: true)
  end

  test "looking up an internal font by name, italic" do
    document = Document.new()

    assert %Fonts.FontReference{module: Pdf.Font.HelveticaOblique} =
             Fonts.get_font(document.fonts, "Helvetica", italic: true)
  end

  test "looking up an internal font by name, bold, italic" do
    document = Document.new()

    assert %Fonts.FontReference{module: Pdf.Font.HelveticaBoldOblique} =
             Fonts.get_font(document.fonts, "Helvetica", italic: true, bold: true)
  end

  test "cannot look up an internal font by name, that has no variants" do
    document = Document.new()

    refute Fonts.get_font(document.fonts, "Symbol", bold: true)
  end

  test "Looking up an external font by name" do
    document =
      Document.new()
      |> Document.add_external_font("test/fonts/Verdana.afm")

    assert %Fonts.FontReference{module: %ExternalFont{name: "Verdana"}} =
             Fonts.get_font(document.fonts, "Verdana", [])
  end

  test "Looking up an external font by font, and variant" do
    document =
      Document.new()
      |> Document.add_external_font("test/fonts/Verdana.afm")
      |> Document.add_external_font("test/fonts/Verdana-Bold.afm")

    assert %Fonts.FontReference{module: %ExternalFont{name: "Verdana-Bold"}} =
             Fonts.get_font(document.fonts, %ExternalFont{family_name: "Verdana"}, bold: true)
  end

  test "Looking up an external font by name, and non-existing variant" do
    document =
      Document.new()
      |> Document.add_external_font("test/fonts/Verdana.afm")

    refute Fonts.get_font(document.fonts, %ExternalFont{family_name: "Verdana"}, bold: true)
  end
end
