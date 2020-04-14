# Pdf
[![Build Status](https://travis-ci.org/andrewtimberlake/elixir-pdf.svg?branch=master)](https://travis-ci.org/andrewtimberlake/elixir-pdf)

The missing PDF library for Elixir.

## Usage

```elixir
Pdf.build([size: :a4, compress: true], fn pdf ->
  pdf
  |> Pdf.set_info(title: "Demo PDF")
  |> Pdf.set_font("Helvetica", 10)
  |> Pdf.text_at({200,200}, "Welcome to Pdf")
  |> Pdf.write_to("test.pdf")
end)
```

## Installation

Add `pdf` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:pdf, "~> 0.3"}]
end
```
