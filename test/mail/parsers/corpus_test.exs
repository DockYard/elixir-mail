defmodule Mail.Parsers.CorpusTest do
  use ExUnit.Case, async: true

  "/Users/andrew/tmp/emails/**/*"
  |> Path.wildcard
  |> Enum.reject(&File.dir?/1)
  |> Enum.each(fn(f) ->
    test "parse corpus email #{inspect(f)}" do
      _mail =
        unquote(f)
        |> File.read!
        |> Mail.Parsers.RFC2822.parse
      # No assertion, just making sure they parse without error
    end
  end)

  @email "/Users/andrew/tmp/emails/54130b67f450126b8c000005"
  test "parse email #{@email}" do
    @email
    |> File.read!
    |> Mail.Parsers.RFC2822.parse
  end
end
