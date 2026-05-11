defmodule Mail.Headers do
  @moduledoc """
  Ordered, multi-valued header storage.

  Headers are stored as a list of `{name, value}` tuples in insertion order.
  Header names are normalized to lowercase and `_` is converted to `-`.
  """

  @behaviour Access

  @type header_name :: String.t()
  @type header_value :: any()
  @type item :: {header_name(), header_value()}

  defstruct items: []

  @type t :: %__MODULE__{items: [item()]}

  @spec new() :: t()
  def new, do: %__MODULE__{items: []}

  @spec to_list(t()) :: [item()]
  def to_list(%__MODULE__{items: items}), do: items

  @spec normalize_name(atom() | String.t()) :: header_name()
  def normalize_name(name) when is_atom(name), do: name |> Atom.to_string() |> normalize_name()

  def normalize_name(name) when is_binary(name) do
    name
    |> String.downcase()
    |> String.replace("_", "-")
  end

  @spec values(t(), atom() | String.t()) :: [header_value()]
  def values(%__MODULE__{items: items}, name) do
    normalized = normalize_name(name)

    items
    |> Enum.reduce([], fn
      {^normalized, value}, acc -> [value | acc]
      _other, acc -> acc
    end)
    |> Enum.reverse()
  end

  @spec has?(t(), atom() | String.t()) :: boolean()
  def has?(%__MODULE__{} = headers, name) do
    normalized = normalize_name(name)
    Enum.any?(headers.items, fn {k, _v} -> k == normalized end)
  end

  @spec delete(t(), atom() | String.t()) :: t()
  def delete(%__MODULE__{} = headers, name) do
    normalized = normalize_name(name)
    %{headers | items: Enum.reject(headers.items, fn {k, _v} -> k == normalized end)}
  end

  @spec put(t(), atom() | String.t(), header_value()) :: t()
  def put(%__MODULE__{} = headers, name, value) do
    normalized = normalize_name(name)

    headers
    |> delete(normalized)
    |> append(normalized, value)
  end

  @spec append(t(), atom() | String.t(), header_value()) :: t()
  def append(%__MODULE__{} = headers, name, value) do
    normalized = normalize_name(name)
    %{headers | items: headers.items ++ [{normalized, value}]}
  end

  @spec prepend(t(), atom() | String.t(), header_value()) :: t()
  def prepend(%__MODULE__{} = headers, name, value) do
    normalized = normalize_name(name)
    %{headers | items: [{normalized, value} | headers.items]}
  end

  @doc """
  Prepends every `{name, value}` from `source` onto `target`, preserving `source`'s
  order as a block before `target`'s existing headers.

  Duplicate names (including repeated keys in `source`) are kept; this does not
  merge or replace by header name.
  """
  @spec prepend_headers(t(), t() | [item()]) :: t()
  def prepend_headers(%__MODULE__{} = target, %__MODULE__{items: items}),
    do: prepend_headers(target, items)

  def prepend_headers(%__MODULE__{} = target, items) when is_list(items) do
    Enum.reduce(Enum.reverse(items), target, fn {name, value}, acc ->
      prepend(acc, name, value)
    end)
  end

  @spec get_single!(t(), atom() | String.t()) :: header_value() | nil
  def get_single!(%__MODULE__{} = headers, name) do
    case values(headers, name) do
      [] ->
        nil

      [value] ->
        value

      [_ | _] ->
        raise ArgumentError, "multiple header values for #{inspect(normalize_name(name))}"
    end
  end

  # Access behaviour:
  # - returns `nil` when missing
  # - returns the single value when exactly one header exists
  # - returns a list of values when multiple headers exist
  @impl Access
  def fetch(%__MODULE__{} = headers, key) do
    normalized = normalize_name(key)

    case values(headers, normalized) do
      [] -> :error
      [value] -> {:ok, value}
      [_ | _] = many -> {:ok, many}
    end
  end

  @impl Access
  def get_and_update(%__MODULE__{} = headers, key, fun) do
    current =
      case values(headers, key) do
        [] -> nil
        [value] -> value
        [_ | _] = many -> many
      end

    case fun.(current) do
      :pop ->
        {current, delete(headers, key)}

      {get, update} ->
        updated =
          case update do
            nil -> delete(headers, key)
            _ -> put(headers, key, update)
          end

        {get, updated}
    end
  end

  @impl Access
  def pop(%__MODULE__{} = headers, key) do
    current =
      case values(headers, key) do
        [] -> nil
        [value] -> value
        [_ | _] = many -> many
      end

    {current, delete(headers, key)}
  end
end

defimpl Enumerable, for: Mail.Headers do
  def count(%Mail.Headers{items: items}), do: {:ok, length(items)}

  def member?(%Mail.Headers{items: items}, element), do: {:ok, element in items}

  def slice(%Mail.Headers{items: items}) do
    {:ok, length(items), fn start, len -> Enum.slice(items, start, len) end}
  end

  def reduce(%Mail.Headers{items: items}, acc, fun), do: Enumerable.List.reduce(items, acc, fun)
end
