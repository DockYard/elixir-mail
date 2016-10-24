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
    |> Pdf.set_font("Helvetica", 12)
    |> Pdf.text_at({10, 400}, "Hello World")
    |> Pdf.text_lines({10, 300}, [
      "First line",
      "Second line",
      "Third line"
      ])
    |> Pdf.write_to(Path.join(__DIR__, "../tmp/test.pdf"))
    |> Pdf.delete
  end

  test "open/2" do
    Pdf.open(fn(pdf) ->
      pdf
    end)
  end
end
