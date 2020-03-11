defmodule Pdf.Font do
  @moduledoc false

  import Pdf.Utils
  alias Pdf.Font.Metrics
  alias Pdf.Encoding.WinAnsi
  alias Pdf.{Array, Dictionary, Text}

  font_metrics =
    Path.join(__DIR__, "../../fonts/*.afm")
    |> Path.wildcard()
    |> Enum.map(fn afm_file ->
      afm_file
      |> File.stream!()
      |> Enum.reduce(%Metrics{}, fn line, metrics ->
        Metrics.process_line(String.replace_suffix(line, "\n", ""), metrics)
      end)
    end)

  font_metrics
  |> Enum.each(fn metrics ->
    font_module = String.to_atom("Elixir.Pdf.Font.#{String.replace(metrics.name, "-", "")}")

    defmodule font_module do
      @doc "The name of the font"
      def name, do: unquote(metrics.name)
      @doc "The full name of the font"
      def full_name, do: unquote(metrics.full_name)
      @doc "The font family of the font"
      def family, do: unquote(metrics.family)
      @doc "The font weight"
      def weight, do: unquote(metrics.weight)
      @doc "The font italic angle"
      def italic_angle, do: unquote(metrics.italic_angle)
      @doc "The font encoding"
      def encoding, do: unquote(metrics.encoding)
      @doc "The first character defined in `widths/0`"
      def first_char, do: unquote(metrics.first_char)
      @doc "The last character defined in `widths/0`"
      def last_char, do: unquote(metrics.last_char)
      @doc "The font ascender"
      def ascender, do: unquote(metrics.ascender)
      @doc "The font descender"
      def descender, do: unquote(metrics.descender)
      @doc "The font cap height"
      def cap_height, do: unquote(metrics.cap_height)
      @doc "The font x-height"
      def x_height, do: unquote(metrics.x_height)

      @doc """
      Returns the character widths of characters beginning from `first_char/0`
      """
      def widths, do: unquote(Metrics.widths(metrics))

      @doc """
      Returns the width of the specific character

      Examples:

          iex> #{inspect(__MODULE__)}.width("A")
          123
      """
      def width(char_code)

      WinAnsi.characters()
      |> Enum.each(fn {char_code, _, name} ->
        case metrics.glyphs[name] do
          nil ->
            def width(unquote(char_code)), do: 0

          %{width: width} ->
            def width(unquote(char_code)), do: unquote(width)
        end
      end)

      @doc ~S"""
      Returns the width of the string in font units (1/1000 of font scale factor)
      """
      def text_width(string), do: text_width(string, [])

      def text_width(string, opts) when is_list(opts) do
        normalized_string = Text.normalize_string(string)

        string_width =
          normalized_string
          |> Enum.reduce(0, &(&2 + width(&1)))

        kerning_adjustments =
          if Keyword.get(opts, :kerning, false) do
            normalized_string
            |> kern_text()
            |> Enum.reject(&is_binary/1)
            |> Enum.reduce(0, &Kernel.+/2)
          else
            0
          end

        string_width - kerning_adjustments
      end

      @doc ~S"""
      Returns the width of a string in points (72 points = 1 inch)
      """
      def text_width(string, font_size) when is_integer(font_size) do
        text_width(string, font_size, [])
      end

      def text_width(string, font_size, opts) when is_integer(font_size) do
        width = text_width(string, opts)
        width * font_size / 1000
      end

      def kern_text([]), do: []

      metrics.kern_pairs
      |> Enum.each(fn {first, second, amount} ->
        def kern_text([unquote(first), unquote(second) | tail]) do
          [<<unquote(first)>>, unquote(-amount) | kern_text([unquote(second) | tail])]
        end
      end)

      def kern_text([first, second | tail]) do
        [<<head::binary>> | tail] = kern_text([second | tail])
        [<<first, head::binary>> | tail]
      end

      def kern_text([char]), do: [<<char>>]
    end
  end)

  @doc ~S"""
  Returns the font module for the named font

  # Example:

  iex> Pdf.Font.lookup("Helvetica-BoldOblique")
  Pdf.Font.HelveticaBoldOblique
  """
  def lookup(name)

  font_metrics
  |> Enum.each(fn metrics ->
    font_module = String.to_atom("Elixir.Pdf.Font.#{String.replace(metrics.name, "-", "")}")
    def lookup(unquote(metrics.name)), do: unquote(font_module)
  end)

  def to_dictionary(font, id) do
    Dictionary.new()
    |> Dictionary.put("Type", n("Font"))
    |> Dictionary.put("Subtype", n("Type1"))
    |> Dictionary.put("Name", n("F#{id}"))
    |> Dictionary.put("BaseFont", n(font.name))
    |> Dictionary.put("FirstChar", 32)
    |> Dictionary.put("LastChar", font.last_char)
    |> Dictionary.put("Widths", Array.new(Enum.drop(font.widths, 32)))
    |> Dictionary.put("Encoding", n("WinAnsiEncoding"))
  end
end
