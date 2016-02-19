defmodule Mail.Assertions.RFC2822 do
  @doc """
  Compares to messages to ensure they are equal

  Will ignore boundary values.
  """
  def assert_rfc2822_equal(actual, expected) do
    actual = Mail.Parsers.RFC2822.parse(actual)
    expected = Mail.Parsers.RFC2822.parse(expected)

    Mail.TestAssertions.compare(actual, expected)
  end
end
