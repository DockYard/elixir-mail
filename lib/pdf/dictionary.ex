defmodule Pdf.Dictionary do
  import Pdf.Size
  import Pdf.Utils

  alias Pdf.Array

  @dict_start "<<\n"
  @dict_start_length byte_size(@dict_start)
  @dict_end ">>"
  @dict_end_length byte_size(@dict_end)
  @initial_length @dict_start_length + @dict_end_length
  @value_separator " "
  @value_separator_length byte_size(@value_separator)
  @entry_separator "\n"
  @entry_separator_length byte_size(@entry_separator)

  defstruct size: @initial_length, entries: %{}

  def new, do: %__MODULE__{size: @initial_length}

  def new(map) do
    map
    |> Enum.reduce(new(), fn {key, value}, dictionary ->
      put(dictionary, key, value)
    end)
  end

  def put(dictionary, key, value) when is_binary(value), do: put(dictionary, key, s(value))

  def put(dictionary, key, value) do
    key = n(key)
    entries = Map.put(dictionary.entries, key, value)
    size = increment_internal_size(dictionary, key, value)
    %{dictionary | entries: entries, size: size}
  end

  defp increment_internal_size(%__MODULE__{size: size}, key, %{size: _size}),
    do: size + size_of(key) + @value_separator_length + @entry_separator_length

  defp increment_internal_size(dictionary, key, value),
    do: increment_internal_size(dictionary, key, %{size: 0}) + size_of(value)

  def size(%__MODULE__{size: size, entries: entries}) do
    calculate_size(Map.to_list(entries), size)
  end

  defp calculate_size([], acc), do: acc

  defp calculate_size([{_key, %__MODULE__{} = dictionary} | tail], acc),
    do: calculate_size(tail, size_of(dictionary) + acc)

  defp calculate_size([{_key, %Array{} = array} | tail], acc),
    do: calculate_size(tail, size_of(array) + acc)

  defp calculate_size([_entry | tail], acc), do: calculate_size(tail, acc)

  def to_iolist(dictionary) do
    [@dict_start, entries_to_iolist(dictionary.entries), @dict_end]
  end

  defp entries_to_iolist(%{} = entries), do: entries_to_iolist(Enum.to_list(entries))
  defp entries_to_iolist([]), do: []
  defp entries_to_iolist([entry | tail]), do: [entry_to_iolist(entry) | entries_to_iolist(tail)]

  defp entry_to_iolist({key, value}),
    do: Pdf.Export.to_iolist([key, @value_separator, value, @entry_separator])

  defimpl Pdf.Size do
    def size_of(%Pdf.Dictionary{} = dictionary), do: Pdf.Dictionary.size(dictionary)
  end

  defimpl Pdf.Export do
    def to_iolist(dictionary), do: Pdf.Dictionary.to_iolist(dictionary)
  end
end
