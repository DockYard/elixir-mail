defmodule PdfTest do
  use ExUnit.Case
  doctest Pdf

  test "test" do
    pid = :eg_pdf.new
    :eg_pdf.set_font(pid, ~c[Helvetica], 12)
    :eg_pdf_lib.moveAndShow(pid, 100, 100, ~c[Hello World])
    :eg_pdf.set_font(pid, ~c[Helvetica-Bold], 12)
    :eg_pdf_lib.moveAndShow(pid, 100, 100, ~c[Hello World])
    {doc, _} = :eg_pdf.export(pid)
    File.write!("/Users/andrew/tmp/tmp.pdf", doc)
    # IO.puts doc
    :eg_pdf.delete(pid)
  end

  test "new/1" do
    {:ok, pdf} = Pdf.new(size: :a4)
    Pdf.delete(pdf)
  end

  test "open/2" do
    Pdf.open(fn(pdf) ->
      pdf
    end)
  end
end

pdf = %{
  header: << "%PDF-1.7\n%", 304, 345, 362, 345, 353, 247, 363, 240, 320, 304, 306 >>,
  objects: [
    %{}
  ]
}
File.write("/Users/andrew/tmp/tmp2.pdf", [pdf.header])
