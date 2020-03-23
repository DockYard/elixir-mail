defmodule Pdf.Utils do
  def c({:command, _} = command), do: command
  def c([] = list), do: {:command, Enum.map(list, &to_string/1)}
  def c(command), do: {:command, command}

  def n({:name, _} = name), do: name
  def n(string) when is_binary(string), do: {:name, string}

  def s({:string, _} = string), do: string
  def s(string), do: {:string, string}

  def a(%Pdf.Array{} = array), do: array
  def a(list), do: Pdf.Array.new(list)
end
