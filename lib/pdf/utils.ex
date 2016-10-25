defmodule Pdf.Utils do
  defmacro n(string),
    do: {:name, string}

  defmacro s(string),
    do: {:string, string}
end
