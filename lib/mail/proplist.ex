defmodule Mail.Proplist do
  @moduledoc """
  A hybrid of erlang's proplists and lists keystores.

  It acts as a Set for key-value pairs, but stil maintains it's order like a
  List.
  """

  @type t :: [{term, term} | term]

  @doc """
  Retrieves all keys from the key value pairs present in the list,
  unlike :proplists.get_keys which will return non-kv pairs as keys

  Args:
  * `list` - a list to retrieve all the keys from
  """
  @spec keys(list :: __MODULE__.t()) :: [term]
  def keys(list) do
    Enum.reduce(list, [], fn
      {key, _value}, acc ->
        if Enum.member?(acc, key) do
          acc
        else
          [key | acc]
        end

      _value, acc ->
        acc
    end)
    |> Enum.reverse()
  end

  @doc """
  Detects if the list contains the specified key.

  Args:
  * `list` - the list to look in
  * `key` - the key to look for
  """
  @spec has_key?(list :: __MODULE__.t(), key :: term) :: [term] | false
  def has_key?(list, key) do
    Enum.any?(list, fn
      {k, _value} -> key == k
      _value -> false
    end)
  end

  @doc """
  Stores a key-value pair in the list, will replace an existing pair with the
  same key.

  Args:
  * `list` - the list to store in
  * `key` - the key of the pair
  * `value` - the value of the pair
  """
  @spec put(list :: __MODULE__.t(), key :: term, value :: term) :: __MODULE__.t()
  def put(list, key, value) do
    :lists.keystore(key, 1, list, {key, value})
  end

  @doc """
  Prepends the key-value pair to the list if it doesn't already exist, otherwise
  it will replace the existing pair

  Args:
  * `list` - the list to store in
  * `key` - the key of the pair
  * `value` - the value of the pair
  """
  @spec prepend(list :: __MODULE__.t(), key :: term, value :: term) :: __MODULE__.t()
  def prepend(list, key, value) do
    if has_key?(list, key) do
      # replace the existing pair
      put(list, key, value)
    else
      [{key, value} | list]
    end
  end

  @doc """
  Retrieves a value from the list

  Args:
  * `list` - the list to look in
  * `key` - the key of the pair to retrieve it's value
  """
  def get(list, key) do
    case :proplists.get_value(key, list) do
      :undefined -> nil
      value -> value
    end
  end

  @doc """
  Merges duplicate pairs with the latest value.

  Args:
  * `list` - the list to normalize
  """
  @spec normalize(list :: __MODULE__.t()) :: __MODULE__.t()
  def normalize(list) do
    Enum.reduce(list, [], fn
      {key, value}, acc ->
        if has_key?(acc, key) do
          put(acc, key, value)
        else
          [{key, value} | acc]
        end

      value, acc ->
        [value | acc]
    end)
    |> Enum.reverse()
  end

  @doc """
  Concatentates the given lists.

  Args:
  * `a` - base list to merge unto
  * `b` - list to merge with
  """
  @spec merge(a :: __MODULE__.t(), b :: __MODULE__.t()) :: __MODULE__.t()
  def merge(a, b) do
    Enum.reduce(b, Enum.reverse(a), fn
      {key, v}, acc -> prepend(acc, key, v)
      value, acc -> [value | acc]
    end)
    |> Enum.reverse()
  end

  @doc """
  Removes a key-value pair by the given key and returns the remaining list

  Args:
  * `list` - the list to remove the pair from
  * `key` - the key to remove
  """
  @spec delete(list :: __MODULE__.t(), key :: term) :: __MODULE__.t()
  def delete(list, key) do
    :proplists.delete(key, list)
  end

  @doc """
  Filters the proplist, i.e. returns only those elements
  for which `fun` returns a truthy value.

  Args:
  * `list` - the list to filter
  * `func` - the function to execute
  """
  @spec filter(list :: __MODULE__.t(), func :: any) :: __MODULE__.t()
  def filter(list, func) do
    Enum.filter(list, fn
      {_key, _value} = value -> func.(value)
      _value -> true
    end)
  end

  @doc """
  Drops the specified keys from the list, returning the remaining.

  Args:
  * `list` - the list
  * `keys` - the keys to remove
  """
  @spec drop(list :: __MODULE__.t(), keys :: list) :: __MODULE__.t()
  def drop(list, keys) do
    filter(list, fn {key, _value} -> !Enum.member?(keys, key) end)
  end

  @doc """
  Takes the specified keys from the list, returning the remaining.

  Args:
  * `list` - the list
  * `keys` - the keys to keep
  """
  @spec take(list :: __MODULE__.t(), keys :: list) :: __MODULE__.t()
  def take(list, keys) do
    filter(list, fn {key, _value} -> Enum.member?(keys, key) end)
  end
end
