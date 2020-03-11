defmodule Pdf.Text do
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
