defmodule Pdf.PageTest do
  use ExUnit.Case, async: true

  alias Pdf.{Page, Fonts, ObjectCollection}

  setup do
    {:ok, collection} = ObjectCollection.start_link()
    {:ok, fonts} = Fonts.start_link(collection)
    page = Page.new(fonts: fonts)

    # Preload fonts so the internal names are fixed (but don't save the resulting stream)
    page
    |> Page.set_font("Helvetica", 12)
    |> Page.set_font("Helvetica", 12, bold: true)
    |> Page.set_font("Helvetica", 12, italic: true)
    |> Page.set_font("Helvetica", 12, bold: true, italic: true)

    {:ok, page: page}
  end

  describe "set_fill_color/2" do
    test "it sets the fill color", %{page: page} do
      page = Page.set_fill_color(page, :red)
      assert page.fill_color == :red
      assert export(page) == "1.0 0.0 0.0 rg\n"
    end

    test "it doesn't log a repeat command", %{page: page} do
      page = Page.set_fill_color(page, :red)
      page = Page.set_fill_color(page, :red)
      assert page.fill_color == :red
      assert export(page) == "1.0 0.0 0.0 rg\n"
    end
  end

  describe "text operations" do
    test "automatically wrapping text commands within BT and ET", %{page: page} do
      page = Page.set_font(page, "Helvetica", 12)
      page = Page.text_at(page, {10, 20}, "Hello world")

      assert export(page) ==
               """
               /F1 12 Tf
               BT
               10 20 Td
               (Hello world) Tj
               ET
               """
    end
  end

  describe "text_at/4" do
    test "accepts a string", %{page: page} do
      page = Page.set_font(page, "Helvetica", 12)
      page = Page.text_at(page, {10, 20}, "Hello world")

      assert export(page) ==
               """
               /F1 12 Tf
               BT
               10 20 Td
               (Hello world) Tj
               ET
               """
    end

    test "accepts attributed text", %{page: page} do
      page = Page.set_font(page, "Helvetica", 12)

      page =
        Page.text_at(page, {10, 20}, [
          "Hello ",
          {"world: ", color: :red, bold: true},
          {"foo, ", size: 14},
          {"bar, ", italic: true},
          {"baz"}
        ])

      assert export(page) == """
             /F1 12 Tf
             BT
             10 20 Td
             (Hello ) Tj
             30.672 0 TD
             /F2 12 Tf
             1.0 0.0 0.0 rg
             (world: ) Tj
             39.336 0 TD
             /F1 14 Tf
             0.0 0.0 0.0 rg
             (foo, ) Tj
             27.244 0 TD
             /F3 12 Tf
             (bar, ) Tj
             24.012 0 TD
             /F1 12 Tf
             (baz) Tj
             19.344 0 TD
             ET
             """
    end
  end

  defp export(%{stream: stream}) do
    (stream
     |> Pdf.Export.to_iolist()
     |> Pdf.Export.to_iolist()
     |> IO.chardata_to_string()
     |> String.split("\n")
     |> Enum.drop_while(&(&1 != "stream"))
     |> Enum.drop(1)
     |> Enum.take_while(&(&1 != "endstream"))
     |> Enum.join("\n")) <> "\n"
  end
end
