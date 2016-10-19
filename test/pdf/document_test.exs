defmodule Pdf.DocumentTest do
  use ExUnit.Case, async: true

  alias Pdf.{Document,Page}

  test "" do
    page =
      Page.new
      |> Page.push("/F1 12 Tf")
      |> Page.push("BT")
      |> Page.push("100 100 Td")
      |> Page.push("(Hello World) Tj")
      |> Page.push("ET")

    Document.new
    |> Document.put_info(:title, "(Test Document)")
    |> Document.put_info(:creator, "(Elixir)")
    |> Document.put_info(:producer, "(Elixir-PDF)")
    |> Document.put_info(:created, DateTime.utc_now)
    |> Document.put_font("Helvetica")
    |> Document.add_page(page)
    |> Document.to_iolist
    # |> IO.inspect
    |> write_to_file("/Users/andrew/tmp/document.pdf")
  end

  defp write_to_file(iolist, path),
    do: File.write!(path, iolist)
end
