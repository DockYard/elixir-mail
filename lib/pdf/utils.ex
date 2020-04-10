defmodule Pdf.Utils do
  @moduledoc false
  @doc false
  def c({:command, _} = command), do: command
  def c([] = list), do: {:command, Enum.map(list, &to_string/1)}
  def c(command), do: {:command, command}

  @doc false
  def n({:name, _} = name), do: name
  def n(string) when is_binary(string), do: {:name, string}

  @doc false
  def s({:string, _} = string), do: string
  def s(string), do: {:string, string}

  @doc false
  def a(%Pdf.Array{} = array), do: array
  def a(list), do: Pdf.Array.new(list)
end
