defmodule Pdf.Image do
  defstruct bits: nil,
            width: nil,
            height: nil,
            color_type: nil,
            size: nil,
            data: nil,
            dictionary: nil

  import Pdf.Size

  @stream_start "\nstream\n"
  @stream_end "endstream\n"

  def new({:binary, image_data}, objects) do
    case identify_image(image_data) do
      :jpeg ->
        Pdf.Images.JPEG.prepare_image(image_data)

      :png ->
        Pdf.Images.PNG.prepare_image(image_data, objects)

      _else ->
        {:error, :image_format_not_recognised}
    end
  end

  def new(image_path, objects) do
    new({:binary, File.read!(image_path)}, objects)
  end

  def identify_image(<<255, 216, _rest::binary>>), do: :jpeg
  def identify_image(<<137, 80, 78, 71, 13, 10, 26, 10, _rest::binary>>), do: :png
  def identify_image(_), do: {:error, :image_format_not_recognised}

  def size(%__MODULE__{size: size, dictionary: dictionary}) do
    size_of(dictionary) + size + byte_size(@stream_start <> @stream_end)
  end

  def to_iolist(%__MODULE__{data: data, dictionary: dictionary}) do
    Pdf.Export.to_iolist(
      Enum.filter(
        [
          dictionary,
          @stream_start,
          data,
          @stream_end
        ],
        & &1
      )
    )
  end

  defimpl Pdf.Size do
    def size_of(%Pdf.Image{} = image), do: Pdf.Image.size(image)
  end

  defimpl Pdf.Export do
    def to_iolist(%Pdf.Image{} = image), do: Pdf.Image.to_iolist(image)
  end
end
