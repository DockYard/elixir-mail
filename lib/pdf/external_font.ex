defmodule Pdf.ExternalFont do
  @moduledoc false
  defstruct name: nil,
            font_file: nil,
            dictionary: nil,
            full_name: nil,
            family_name: nil,
            weight: nil,
            italic_angle: nil,
            encoding: nil,
            first_char: 0,
            last_char: 255,
            ascender: nil,
            descender: nil,
            cap_height: 0,
            x_height: nil,
            fixed_pitch: false,
            bbox: nil,
            widths: [],
            glyphs: %{},
            kern_pairs: []

  import Pdf.Utils
  alias Pdf.Font.Metrics
  alias Pdf.{Array, Dictionary}

  @stream_start "\nstream\n"
  @stream_end "\nendstream"

  def load(path) do
    font_metrics =
      path
      |> File.stream!()
      |> Enum.reduce(%Metrics{}, fn line, metrics ->
        Metrics.process_line(String.replace_suffix(line, "\n", ""), metrics)
      end)

    font_file_name = Path.rootname(path) <> ".pfb"
    font_file = File.read!(font_file_name)

    part1 = (:binary.match(font_file, "eexec") |> elem(0)) + 6
    part2 = (:binary.match(font_file, "00000000") |> elem(0)) - part1
    part3 = byte_size(font_file) - part1 - part2

    widths = Metrics.widths(font_metrics)
    last_char = font_metrics.first_char + length(widths) - 1

    %__MODULE__{
      name: font_metrics.name,
      font_file: font_file,
      dictionary: font_file_dictionary(part1, part2, part3),
      full_name: font_metrics.full_name,
      family_name: font_metrics.family_name,
      weight: font_metrics.weight,
      italic_angle: font_metrics.italic_angle,
      encoding: font_metrics.encoding,
      first_char: font_metrics.first_char,
      last_char: last_char,
      ascender: font_metrics.ascender,
      descender: font_metrics.descender,
      cap_height: font_metrics.cap_height || 0,
      x_height: font_metrics.x_height,
      fixed_pitch: font_metrics.fixed_pitch,
      bbox: font_metrics.bbox,
      widths: widths,
      glyphs: font_metrics.glyphs,
      kern_pairs: font_metrics.kern_pairs
    }
  end

  def font_dictionary(font, id, desc_id) do
    Dictionary.new()
    |> Dictionary.put("Type", n("Font"))
    |> Dictionary.put("Subtype", n("Type1"))
    |> Dictionary.put("Name", n("F#{id}"))
    |> Dictionary.put("BaseFont", n(font.name))
    |> Dictionary.put("FirstChar", font.first_char)
    |> Dictionary.put("LastChar", font.last_char)
    |> Dictionary.put("Widths", Array.new(Enum.map(font.widths, &to_string/1)))
    |> Dictionary.put("Encoding", n("WinAnsiEncoding"))
    |> Dictionary.put("FontDescriptor", desc_id)
  end

  def font_descriptor_dictionary(font, ff_id) do
    flags = 32

    Dictionary.new()
    |> Dictionary.put("Type", n("FontDescriptor"))
    |> Dictionary.put("Flags", flags)
    |> Dictionary.put("FontName", n(font.name))
    |> Dictionary.put("StemV", 100)
    |> Dictionary.put("Ascent", font.ascender / 1)
    |> Dictionary.put("Descent", font.descender / 1)
    |> Dictionary.put("FontBBox", Array.new(Tuple.to_list(font.bbox)))
    |> Dictionary.put("ItalicAngle", font.italic_angle)
    |> Dictionary.put("CapHeight", font.cap_height / 1)
    |> Dictionary.put("FontFile", ff_id)
  end

  def font_file_dictionary(part1, part2, part3) do
    Dictionary.new()
    |> Dictionary.put("Length1", part1)
    |> Dictionary.put("Length2", part2)
    |> Dictionary.put("Length3", part3)
    |> Dictionary.put("Length", part1 + part2 + part3)
  end

  def size(%__MODULE__{} = font) do
    # size_of(font.dictionary) + byte_size(font.font_file) + byte_size(@stream_start <> @stream_end)
    byte_size(to_iolist(font) |> Enum.join())
  end

  @doc """
  Returns the width of the specific character

  Examples:

    iex> ExternalFont.width(font, "A")
    123
  """
  def width(font, <<char_code::integer>> = str) when is_binary(str) do
    width(font, char_code)
  end

  def width(font, char_code) do
    Pdf.Encoding.WinAnsi.characters()
    |> Enum.find(fn {_, char, _} -> char == char_code end)
    |> case do
      nil ->
        0

      {_, _, name} ->
        case font.glyphs[name] do
          nil ->
            0

          %{width: width} ->
            width
        end
    end
  end

  def kern_text(_font, ""), do: [""]

  def kern_text(font, <<first::integer, second::integer, rest::binary>>) do
    font.kern_pairs
    |> Enum.find(fn {f, s, _amount} -> f == first && s == second end)
    |> case do
      {f, _s, amount} ->
        [<<f>>, -amount | kern_text(font, <<second::integer, rest::binary>>)]

      nil ->
        [head | tail] = kern_text(font, <<second::integer, rest::binary>>)
        [<<first::integer, head::binary>> | tail]
    end
  end

  def kern_text(_font, <<_::integer>> = char), do: [char]

  def to_iolist(%__MODULE__{} = font) do
    Pdf.Export.to_iolist([
      font.dictionary,
      @stream_start,
      font.font_file,
      @stream_end
    ])
  end

  defimpl Pdf.Size do
    def size_of(%Pdf.ExternalFont{} = font), do: Pdf.ExternalFont.size(font)
  end

  defimpl Pdf.Export do
    def to_iolist(%Pdf.ExternalFont{} = font), do: Pdf.ExternalFont.to_iolist(font)
  end
end
