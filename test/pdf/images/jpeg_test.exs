defmodule Pdf.Images.JPEGTest do
  use Pdf.Case, async: true

  alias Pdf.Images.JPEG

  test "decode/1" do
    assert JPEG.decode(fixture("rgb.jpg")) == {:ok, {8, 75, 100, 3}}
    assert JPEG.decode(fixture("cmyk.jpg")) == {:ok, {8, 75, 100, 4}}
    assert JPEG.decode(fixture("grayscale.jpg")) == {:ok, {8, 75, 100, 1}}
  end
end
