defmodule PdfTest do
  use ExUnit.Case
  doctest Pdf

  test "test" do
  end

  test "new/1" do
    {:ok, pdf} = Pdf.new(size: :a4)
    pdf
    |> Pdf.set_author("Test Author")
    |> Pdf.set_creator("Test Creator")
    |> Pdf.set_keywords("word word word")
    |> Pdf.set_producer("Test producer")
    |> Pdf.set_subject("Test Subject")
    |> Pdf.set_title("Test Document")
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
