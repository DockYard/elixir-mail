defmodule Pdf.Text do
  def chunk_text(string, font, font_size, opts \\ []) do
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
    |> Enum.map(&{&1, font.text_width(&1, font_size, opts), opts})
  end

  def wrap_chunks(chunks, width) do
    fit_chunks(chunks, width)
  end

  defp fit_chunks(chunks, wrap_width, acc_width \\ 0, acc \\ [])

  defp fit_chunks([{"\n", _, _} = chunk | tail], _wrap_width, _acc_width, acc) do
    {Enum.reverse([chunk | remove_wrapped_whitespace(acc)]), remove_wrapped_whitespace(tail)}
  end

  defp fit_chunks([{_, width, _} = chunk | tail], wrap_width, acc_width, [
         {"\u00AD", hyphen_width, _} | acc
       ])
       when width + acc_width - hyphen_width <= wrap_width do
    fit_chunks(tail, wrap_width, acc_width + width, [chunk | acc])
  end

  defp fit_chunks([{_, width, _} = chunk | tail], wrap_width, acc_width, acc)
       when width + acc_width <= wrap_width do
    fit_chunks(tail, wrap_width, acc_width + width, [chunk | acc])
  end

  defp fit_chunks(chunks, _wrap_width, _acc_width, acc) do
    {Enum.reverse(remove_wrapped_whitespace(acc)), remove_wrapped_whitespace(chunks)}
  end

  defp remove_wrapped_whitespace([{" ", _, _} | tail]), do: tail
  defp remove_wrapped_whitespace([{"\u200B", _, _} | tail]), do: tail
  defp remove_wrapped_whitespace(chunks), do: chunks

  def wrap(string, width, font, font_size, opts \\ []) do
    string
    |> chunk_text(font, font_size, opts)
    |> wrap_all_chunks(width)
    |> Enum.map(fn chunks ->
      chunks
      |> Enum.reject(&(elem(&1, 1) == 0.00))
      |> Enum.map(&elem(&1, 0))
      |> Enum.join()
    end)
  end

  defp wrap_all_chunks(chunks, width, acc \\ [])

  defp wrap_all_chunks([], _width, acc), do: Enum.reverse(acc)

  defp wrap_all_chunks(chunks, width, acc) do
    case wrap_chunks(chunks, width) do
      {[], [chunk | tail]} -> wrap_all_chunks(tail, width, [[chunk] | acc])
      {chunks, tail} -> wrap_all_chunks(tail, width, [chunks | acc])
    end
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
