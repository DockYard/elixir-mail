defmodule Pdf.Dictionary do
  defstruct size: 5, entries: %{}

  @dict_start "<< "
  @dict_end ">>"
  @key_prefix "/"
  @key_prefix_length 1
  @value_separator " "
  @value_separator_length 1
  @entry_separator "\n"
  @entry_separator_length 1

  def add(dictionary, key, %__MODULE__{} = value) do
    entries = Map.put(dictionary.entries, key, value)
    size = @key_prefix_length + String.length(key) + @value_separator_length + @entry_separator_length
    %{dictionary | entries: entries, size: dictionary.size + size}
  end
  def add(dictionary, key, value) do
    entries = Map.put(dictionary.entries, key, value)
    size = @key_prefix_length + String.length(key) + @value_separator_length + String.length(value) + @entry_separator_length
    %{dictionary | entries: entries, size: dictionary.size + size}
  end

  def size(%__MODULE__{size: size, entries: entries}) do
    calculate_size(Map.to_list(entries), size)
  end

  defp calculate_size([], acc), do: acc
  defp calculate_size([{_key, %__MODULE__{} = dictionary} | tail], acc),
    do: calculate_size(tail, __MODULE__.size(dictionary) + acc)
  defp calculate_size([_entry | tail], acc),
    do: calculate_size(tail, acc)

  def to_iolist(%__MODULE__{} = dictionary) do
    [@dict_start, entries_to_iolist(dictionary.entries), @dict_end]
  end

  defp entries_to_iolist(%{} = entries),
    do: entries_to_iolist(Enum.to_list(entries))
  defp entries_to_iolist([]), do: []
  defp entries_to_iolist([entry | tail]),
    do: [entry_to_iolist(entry) | entries_to_iolist(tail)]

  defp entry_to_iolist({key, value}),
    do: [@key_prefix, key, @value_separator, value_to_iolist(value), @entry_separator]

  defp value_to_iolist(%__MODULE__{} = value),
    do: to_iolist(value)
  defp value_to_iolist(value),
    do: value
end
