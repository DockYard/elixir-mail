defmodule Pdf.PaperTest do
  use ExUnit.Case, async: true

  alias Pdf.Paper

  test "size/1 by name" do
    assert Paper.size(:a4) == [0, 0, 595, 842]
    assert Paper.size({:a4, :landscape}) == [0, 0, 842, 595]
  end

  test "size/1 with width and height" do
    assert Paper.size([595, 842]) == [0, 0, 595, 842]
  end
end
