defmodule Pdf.RefTableTest do
  use ExUnit.Case, async: true

  alias Pdf.{RefTable,Object}

  test "" do
    iolist = RefTable.to_iolist([
      Object.new(1, "A string"),
      Object.new(2, "Another string"),
      Object.new(3, "A third string")
    ])

    assert iolist == {["xref\n", "0", " ", "4", "\n", "0000000000 65535 f\n",
                      [
                        ["0000000000", " ", "00000", " n\n"],
                        ["0000000026", " ", "00000", " n\n"],
                        ["0000000058", " ", "00000", " n\n"],
                      ]], 90}
  end
end
