defmodule Pdf.Images.PNGTest do
  use Pdf.Case, async: true

  alias Pdf.Images.PNG

  test "decode/1" do
    assert %{bit_depth: 8, height: 75, width: 100, color_type: 0} =
             PNG.decode(File.read!(fixture("grayscale.png")))

    assert %{bit_depth: 8, height: 75, width: 100, color_type: 2} =
             PNG.decode(File.read!(fixture("truecolour.png")))

    assert %{bit_depth: 8, height: 75, width: 100, color_type: 3} =
             PNG.decode(File.read!(fixture("indexed.png")))

    assert %{bit_depth: 8, height: 75, width: 100, color_type: 4} =
             PNG.decode(File.read!(fixture("grayscale-alpha.png")))

    assert %{bit_depth: 8, height: 75, width: 100, color_type: 6} =
             PNG.decode(File.read!(fixture("truecolour-alpha.png")))
  end
end
