defmodule Mail.TestAssertions do
  import ExUnit.Assertions

  @moduledoc """
  Primitives for building your own assertions for Mail.Message
  renderers.

  A custom assertion should implement its own parser. The result of the
  parsing the actual message and the expected message is then passed
  into `compare/2`
  """

  @doc """
  Primary hook used by rendered mail assertions. Expected parsed
  messages.
  """
  def compare(%Mail.Message{multipart: left_multipart?}, %Mail.Message{
        multipart: right_multipart?
      })
      when left_multipart? != right_multipart?,
      do: raise(ExUnit.AssertionError, message: "one message is multipart, the other is not")

  def compare(%Mail.Message{} = actual, %Mail.Message{} = expected) do
    compare_headers(actual.headers, expected.headers)
    compare_bodies(actual, expected)
  end

  defp compare_headers(actual, expected) do
    actual = normalize_boundary(actual)
    expected = normalize_boundary(expected)

    Enum.each(actual, fn {key, value} ->
      cond do
        value != expected[key] ->
          raise(ExUnit.AssertionError, message: "header key `#{key}` is not equal")

        true ->
          nil
      end
    end)
  end

  defp compare_bodies(
         %Mail.Message{multipart: true} = actual,
         %Mail.Message{multipart: true} = expected
       ) do
    assert length(actual.parts) == length(expected.parts),
           "actual and expected must have equal number of parts"

    compare_parts(actual.parts, expected.parts)
  end

  defp compare_bodies(%Mail.Message{} = actual, %Mail.Message{} = expected) do
    assert actual.body == expected.body
  end

  defp compare_parts([], []), do: nil

  defp compare_parts([actual_head | actual_tail], [expected_head | expected_tail]) do
    compare(actual_head, expected_head)
    compare_parts(actual_tail, expected_tail)
  end

  defp normalize_boundary(headers) do
    content_type =
      headers["content-type"]
      |> List.wrap()

    content_type
    |> Mail.Proplist.get("boundary")
    |> case do
      nil ->
        headers

      _boundary ->
        content_type = Mail.Proplist.put(content_type, "boundary", "")
        put_in(headers, ["content-type"], content_type)
    end
  end
end
