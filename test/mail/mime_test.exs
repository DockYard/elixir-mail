defmodule Mail.MIMETest do
  use ExUnit.Case, async: true

  @types_file Path.expand("../../lib/mail/mime.types", __DIR__)

  test "every extension in mime.types resolves to the first type that lists it" do
    expected =
      @types_file
      |> File.read!()
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "#")))
      |> Enum.flat_map(fn line ->
        [type | extensions] = String.split(line)
        Enum.map(extensions, &{&1, type})
      end)
      |> Enum.uniq_by(fn {extension, _type} -> extension end)

    assert length(expected) > 100

    for {extension, type} <- expected do
      assert Mail.MIME.type(extension) == type, "#{extension} should map to #{type}"
    end
  end

  test "an extension absent from mime.types resolves to nil" do
    assert Mail.MIME.type("not-an-extension") == nil
  end
end
