defmodule Mail.Proplist do
  @type t :: [{term, term} | term]

  @spec keys(list :: __MODULE__.t) :: [term]
  def keys(list) do
    Enum.reduce(list, [], fn
      {key, _value}, acc ->
        if Enum.member?(acc, key) do
          acc
        else
          [key | acc]
        end

      value, acc -> acc
    end)
    |> Enum.reverse()
  end

  @spec put(list :: __MODULE__.t, key :: term, value :: term) :: __MODULE__.t
  def put(list, key, value) do
    :lists.keystore(key, 1, list, {key, value})
  end

  @spec get(list :: __MODULE__.t, key :: term) :: __MODULE__.t
  def get(list, key) do
    case :proplists.get_value(key, list) do
      :undefined -> nil
      value -> value
    end
  end

  @spec merge(a :: __MODULE__.t, b :: __MODULE__.t) :: __MODULE__.t
  def merge(a, b) do
    Enum.reduce(a ++ b, [], fn
      {key, _value} = value, acc ->
        if Enum.any?(acc, fn
            {subkey, _value} -> key == subkey
            value -> false
          end) do
          :lists.keystore(key, 1, acc, value)
        else
          [value | acc]
        end
      value, acc ->
        [value | acc]
    end)
    |> Enum.reverse()
  end

  @spec delete(list :: __MODULE__.t, key :: term) :: __MODULE__.t
  def delete(list, key) do
    :proplists.delete(key, list)
  end

  @spec filter(list :: __MODULE__.t, func :: any) :: __MODULE__.t
  def filter(list, func) do
    Enum.filter(list, fn
      {key, _value} = value -> func.(value)
      value -> true
    end)
  end

  @spec drop(list :: __MODULE__.t, keys :: list) :: __MODULE__.t
  def drop(list, keys) do
    filter(list, fn {key, value} -> !Enum.member?(keys, key) end)
  end

  @spec take(list :: __MODULE__.t, keys :: list) :: __MODULE__.t
  def take(list, keys) do
    filter(list, fn {key, value} -> Enum.member?(keys, key) end)
  end
end
