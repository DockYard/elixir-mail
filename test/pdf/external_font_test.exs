defmodule Pdf.ExternalFontTest do
  use ExUnit.Case, asyn: true

  alias Pdf.ExternalFont
  alias Pdf.Size
  alias Pdf.Export

  @font "Verdana-Bold"

  setup do
    %ExternalFont{} = font = ExternalFont.load("test/fonts/#{@font}.afm")
    %{font: font}
  end

  test "font metrics", %{font: font} do
    metrics = font.metrics

    assert metrics.name == @font
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
end
