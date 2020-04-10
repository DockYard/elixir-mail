# Pdf

The missing PDF library for Elixir.

## Usage

```elixir

  {:ok, pdf} = Pdf.new( size: :a4, compress: true)

  report =
    pdf 
    |> Pdf.set_info(title: "Demo PDF")
    |> Pdf.set_font("Helvetica", 10)
    |> Pdf.text_at({200,200}, "Welcome to Pdf")
    |> Pdf.write_to("test.pdf")

  Pdf.delete(pdf)

```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  Add `pdf` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:pdf, "~> 0.3.4"}]
    end
    ```

