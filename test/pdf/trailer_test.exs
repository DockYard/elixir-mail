defmodule Pdf.TrailerTest do
  use ExUnit.Case, async: true

  alias Pdf.Trailer

  test "" do
    root = {:object, 1, 0}
    info = {:object, 2, 0}
    objects = [root, info, {:object, 3, 0}]
    iolist = Pdf.Export.to_iolist(Trailer.new(objects, 42, root, info))

    assert iolist == ["trailer\n", [
                         "<<\n",[
                           [["/", "Info"], " ", ["2", " ", "0", " R"], "\n"],
                           [["/", "Root"], " ", ["1", " ", "0", " R"], "\n"],
                           [["/", "Size"], " ", "4", "\n"]
                         ], ">>"],
                      "\nstartxref\n", "42", "\n%%EOF"]
  end
end
