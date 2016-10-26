defmodule Pdf.Images.JPEG do
  @file_chunk_size 500

  @doc ~S"""
  Decodes an image and returns the bit depth, height, width and colour channels

  Examples:

      > Pdf.Image.JPEG.decode("path/to/image.jpg")
      {:ok, {8, 75, 100, 3}) # 8 bits, height: 75px, width: 100px, channels: 3 (RGB)
  """
  def decode(image_path) do
    io = File.open!(image_path, [:read, :compressed, :binary, :raw])
    {:ok, data, io} = get_chunk(io)
    results = parse_jpeg(data, io)
    File.close(io)
    results
  end

  defp parse_jpeg(<<255, 216, rest :: binary>>, io),
    do: parse_jpeg(rest, io)
  defp parse_jpeg(data, io) when byte_size(data) < 4 do
    {:ok, data, io} = ensure_length(data, @file_chunk_size, io)
    parse_jpeg(data, io)
  end
  [192, 193, 194, 195, 197, 198, 199, 201, 202, 203, 205, 206, 207] |> Enum.each(fn(code) ->
    defp parse_jpeg(<<255, unquote(code), _length :: unsigned-integer-size(16), rest :: binary>>, io),
      do: parse_image_data(rest, io)
  end)
  defp parse_jpeg(<<255, _code, length :: unsigned-integer-size(16), rest :: binary>>, io) do
    {:ok, data, io} = chomp(rest, length - 2, io)
    parse_jpeg(data, io)
  end
  defp parse_jpeg(_data, _io),
    do: {:error, :not_jpeg}

  def parse_image_data(<<bits, height :: unsigned-integer-size(16), width :: unsigned-integer-size(16), channels, _rest :: binary>>, _io),
    do: {:ok, {bits, height, width, channels}}
  def parse_image_data(_, _),
    do: {:error, :parse_error}

  defp get_chunk(io),
    do: {:ok, IO.binread(io, @file_chunk_size), io}

  defp chomp(data, length, io) do
    {:ok, data, io} = ensure_length(data, length, io)
    data = :erlang.binary_part(data, {length, byte_size(data) - length})
    {:ok, data, io}
  end

  defp ensure_length(data, length, io) when byte_size(data) >= length,
    do: {:ok, data, io}
  defp ensure_length(data, length, io) do
    {:ok, chunk, io} = get_chunk(io)
    ensure_length(data <> chunk, length, io)
  end
end
