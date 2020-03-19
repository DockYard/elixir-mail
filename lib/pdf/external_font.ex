defmodule Pdf.ExternalFont do
  @moduledoc false
  defstruct name: nil,
            font_file: nil,
            metrics: nil,
            dictionary: nil

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
      metrics: %{font_metrics | last_char: last_char, widths: widths},
      font_file: font_file,
      dictionary: font_file_dictionary(part1, part2, part3)
    }
  end

  def font_dictionary(font, id, desc_id) do
    Dictionary.new()
    |> Dictionary.put("Type", n("Font"))
    |> Dictionary.put("Subtype", n("Type1"))
    |> Dictionary.put("Name", n("F#{id}"))
    |> Dictionary.put("BaseFont", n(font.metrics.name))
    |> Dictionary.put("FirstChar", font.metrics.first_char)
    |> Dictionary.put("LastChar", font.metrics.last_char)
    |> Dictionary.put("Widths", Array.new(Enum.map(font.metrics.widths, &to_string/1)))
    |> Dictionary.put("Encoding", n("WinAnsiEncoding"))
    |> Dictionary.put("FontDescriptor", desc_id)
  end

  def font_descriptor_dictionary(font, ff_id) do
    flags = 32

    Dictionary.new()
    |> Dictionary.put("Type", n("FontDescriptor"))
    |> Dictionary.put("Flags", flags)
    |> Dictionary.put("FontName", n(font.metrics.name))
    |> Dictionary.put("StemV", 100)
    |> Dictionary.put("Ascent", font.metrics.ascender / 1)
    |> Dictionary.put("Descent", font.metrics.descender / 1)
    |> Dictionary.put("FontBBox", Array.new(Tuple.to_list(font.metrics.bbox)))
    |> Dictionary.put("ItalicAngle", font.metrics.italic_angle)
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
