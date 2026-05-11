defmodule Mail.TestHelpers.Headers do
  @moduledoc false

  @doc """
  Builds a `%Mail.Headers{}` from a map.

  This is a **lossy** helper intended for tests:
  - maps cannot represent duplicate headers
  - map iteration order is not meaningful for header ordering
  """
  def headers_from_map(map) when is_map(map) do
    map
    |> Enum.sort_by(fn {k, _v} -> to_string(k) end)
    |> Enum.reduce(Mail.Headers.new(), fn {k, v}, acc ->
      Mail.Headers.append(acc, k, v)
    end)
  end
end

