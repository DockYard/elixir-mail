defmodule Mail.TestAssertions do
  import ExUnit.Assertions

  def assert_rfc2822_equal(actual, expected) do
    actual = Mail.Parsers.RFC2822.parse(actual)
    expected = Mail.Parsers.RFC2822.parse(expected)

    compare_message(actual, expected)
  end

  defp compare_message(%Mail.Message{multipart: false}, %Mail.Message{multipart: true}),
    do: raise(ExUnit.AssertionError, message: "messages not equal, actual is not multipart, expected is multipart")
  defp compare_message(%Mail.Message{multipart: true}, %Mail.Message{multipart: false}),
    do: raise(ExUnit.AssertionError, message: "messages not equal, actual is multipart, expected is not multipart")

  defp compare_message(%Mail.Message{} = actual, %Mail.Message{} = expected) do
    compare_headers(actual.headers, expected.headers)
    compare_bodies(actual, expected)
  end

  defp compare_headers(actual, expected) do
    actual = normalize_boundary(actual)
    expected = normalize_boundary(expected)

    Enum.each(actual, fn({key, value}) ->
      cond do
        value != expected[key] ->
          raise(ExUnit.AssertionError, message: "header key #{key} is not equal")
        true -> nil
      end
    end)
  end

  defp compare_bodies(%Mail.Message{multipart: true} = actual, %Mail.Message{multipart: true} = expected) do
    assert length(actual.parts) == length(expected.parts), "actual and expected must have same number of parts"
    compare_parts(actual.parts, expected.parts)
  end

  defp compare_bodies(%Mail.Message{} = actual, %Mail.Message{} = expected) do
    assert actual.body == expected.body
  end

  defp compare_parts([], []), do: nil
  defp compare_parts([actual_head | actual_tail], [expected_head | expected_tail]) do
    compare_message(actual_head, expected_head)
    compare_parts(actual_tail, expected_tail)
  end

  defp normalize_boundary(headers) do
    content_type =
      headers[:content_type]
      |> List.wrap()

    case Keyword.fetch(content_type, :boundary) do
      nil -> headers
      boundary ->
        content_type = put_in(content_type, [:boundary], "")
        put_in(headers, [:content_type], content_type)
    end
  end
end
