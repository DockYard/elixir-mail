defmodule Pdf.Text do
  def wrap(font, font_size, string, width, opts \\ []) do
    zero_width_space = "\u200B"
    soft_hyphen = "\u00AD"
    hyphen = "-"
    whitespace = "\s\t#{zero_width_space}\n"
    break_chars = " \t\n\v\r#{zero_width_space}#{soft_hyphen}#{hyphen}"

    [
      "([^#{break_chars}]+)(#{soft_hyphen})",
      "([^#{break_chars}]+#{hyphen}+)",
      "([^#{break_chars}]+)",
      "([#{whitespace}])",
      "(#{hyphen}+[^#{break_chars}]*)"
    ]
    |> Enum.join("|")
    |> Regex.compile!("u")
    |> Regex.scan(string, capture: :all_but_first)
    |> Enum.flat_map(& &1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&{&1, font.text_width(&1, font_size, opts)})
    |> wrap_chunks(width)
    |> Enum.map(fn chunks ->
      chunks
      |> Enum.map(&elem(&1, 0))
      |> Enum.map(fn
        "\u00A0" -> " "
        str -> str
      end)
      |> Enum.join()
    end)
  end

  defp wrap_chunks(chunks, wrap_width, acc_width \\ 0, acc \\ [])

  defp wrap_chunks([], _wrap_width, _acc_width, []), do: []
  defp wrap_chunks([], _wrap_width, _acc_width, acc), do: [Enum.reverse(acc)]

  defp wrap_chunks([{"\n", _} | tail], wrap_width, _, acc) do
    [Enum.reverse(acc) | wrap_chunks(tail, wrap_width)]
  end

  defp wrap_chunks([{" ", _} | tail], wrap_width, 0, []) do
    wrap_chunks(tail, wrap_width)
  end

  defp wrap_chunks([{"\u200B", _} | tail], wrap_width, acc_width, acc) do
    wrap_chunks(tail, wrap_width, acc_width, acc)
  end

  defp wrap_chunks([{_string, width} = chunk | tail], wrap_width, 0, [])
       when width > wrap_width do
    [[chunk] | wrap_chunks(tail, wrap_width)]
  end

  defp wrap_chunks([{_string, width} = chunk | tail], wrap_width, acc_width, acc)
       when width + acc_width <= wrap_width do
    wrap_chunks(tail, wrap_width, acc_width + width, [chunk | acc])
  end

  defp wrap_chunks([{_string, width} = chunk | tail], wrap_width, acc_width, [
         {"\u00AD", soft_hyphen_width} | acc
       ])
       when width + acc_width - soft_hyphen_width <= wrap_width do
    wrap_chunks(tail, wrap_width, acc_width + width, [chunk | acc])
  end

  defp wrap_chunks(chunks, wrap_width, _acc_width, [{" ", _} | acc]) do
    [Enum.reverse(acc) | wrap_chunks(chunks, wrap_width)]
  end

  defp wrap_chunks(chunks, wrap_width, _acc_width, [{"\t", _} | acc]) do
    [Enum.reverse(acc) | wrap_chunks(chunks, wrap_width)]
  end

  defp wrap_chunks(chunks, wrap_width, _acc_width, [{"\u200B", _} | acc]) do
    [Enum.reverse(acc) | wrap_chunks(chunks, wrap_width)]
  end

  defp wrap_chunks(chunks, wrap_width, _acc_width, acc) do
    [Enum.reverse(acc) | wrap_chunks(chunks, wrap_width)]
  end

  def normalize_string(string) when is_binary(string) do
    string
    |> normalize_unicode_characters()
    |> Pdf.Encoding.WinAnsi.encode()
    |> String.to_charlist()
  end

  # Only available from OTP 20.0
  if Kernel.function_exported?(:unicode, :characters_to_nfc_binary, 1) do
    defp normalize_unicode_characters(string) do
      :unicode.characters_to_nfc_binary(string)
    end
  else
    defp normalize_unicode_characters(string), do: string
  end
end
