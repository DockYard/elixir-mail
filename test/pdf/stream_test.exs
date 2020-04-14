defmodule Pdf.StreamTest do
  use ExUnit.Case, async: true

  alias Pdf.Stream

  test "push/2" do
    stream =
      Stream.new(compress: false)
      |> Stream.push("BT")
      |> Stream.push("100 100 Td")
      |> Stream.push("(Hello World) Tj")
      |> Stream.push("ET")

    iolist = Pdf.Export.to_iolist(stream)

    assert iolist == [
             ["<<\n", [[["/", "Length"], " ", "34", "\n"]], ">>"],
             "\nstream\n",
             [
               "BT",
               "\n",
               "100 100 Td",
               "\n",
               "(Hello World) Tj",
               "\n",
               "ET",
               "\n"
             ],
             "endstream"
           ]
  end

  test "push/2 with compression" do
    stream =
      Stream.new(compress: 6)
      |> Stream.push("BT")
      |> Stream.push("100 100 Td")
      |> Stream.push("(Hello World) Tj")
      |> Stream.push("ET")

    iolist = Pdf.Export.to_iolist(stream)

    assert iolist == [
             [
               "<<\n",
               [
                 [["/", "Filter"], " ", ["/", "FlateDecode"], "\n"],
                 [["/", "Length"], " ", "39", "\n"]
               ],
               ">>"
             ],
             "\nstream\n",
             "x\x9Cs\n\xE1240P\0\xE1\x90\x14.\r\x8FԜ\x9C|\x85\xF0\xFC\xA2\x9C\x14M\x85\x90,.\xD7\x10.\0\x90\x05\b\xBD",
             "endstream"
           ]
  end
end
