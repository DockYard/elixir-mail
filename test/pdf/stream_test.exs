defmodule Pdf.StreamTest do
  use ExUnit.Case, async: true

  alias Pdf.Stream

  test "push/2" do
    stream =
      Stream.new
      |> Stream.push("BT")
      |> Stream.push("100 100 Td")
      |> Stream.push("(Hello World) Tj")
      |> Stream.push("ET")

    iolist = Pdf.Export.to_iolist(stream)
    assert iolist == [["<<\n", [["/", "Length", " ", "34", "\n"]], ">>"],
                      "\nstream\n", [
                        "BT", "\n",
                        "100 100 Td", "\n",
                        "(Hello World) Tj", "\n",
                        "ET", "\n"
                      ], "endstream"]
  end
end
