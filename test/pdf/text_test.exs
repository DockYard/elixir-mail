defmodule Pdf.TextTest do
  use ExUnit.Case, async: true

  alias Pdf.Text

  setup do
    font = Pdf.Font.Helvetica
    font_size = 10
    {:ok, font: font, font_size: font_size}
  end

  describe "chunk_text/4" do
    test "it breaks on a space", %{font: font, font_size: font_size} do
      string = "Hello world"

      assert Text.chunk_text(string, font, font_size) == [
               {"Hello", 22.78, []},
               {" ", 2.78, []},
               {"world", 23.89, []}
             ]

      assert Text.chunk_text(string, font, font_size, kerning: true) == [
               {"Hello", 22.78, [kerning: true]},
               {" ", 2.78, [kerning: true]},
               {"world", 23.94, [kerning: true]}
             ]
    end
  end

  describe "wrap_chunks/2" do
    test "It doesn't include the wrapped space" do
      chunks = [
        {"Hello", 22.78, []},
        {" ", 2.78, []},
        {"world", 26.11, []}
      ]

      assert Text.wrap_chunks(chunks, 23.0) == {[{"Hello", 22.78, []}], [{"world", 26.11, []}]}

      chunks = [
        {"Hello", 22.78, size: 10},
        {" ", 2.78, color: :blue},
        {"world", 26.11, color: :red}
      ]

      assert Text.wrap_chunks(chunks, 23.0) ==
               {[{"Hello", 22.78, size: 10}], [{"world", 26.11, color: :red}]}
    end

    test "it doesn't include a zero-width space" do
      chunks = [
        {"Hello", 22.78, []},
        {"\u200B", 0.00, []},
        {"world", 26.11, []}
      ]

      assert Text.wrap_chunks(chunks, 23.0) == {[{"Hello", 22.78, []}], [{"world", 26.11, []}]}

      chunks = [
        {"Hello", 22.78, color: :blue},
        {"\u200B", 0.00, []},
        {"world", 26.11, size: 10}
      ]

      assert Text.wrap_chunks(chunks, 23.0) ==
               {[{"Hello", 22.78, color: :blue}], [{"world", 26.11, size: 10}]}
    end

    test "it removes unused soft-hyphens" do
      chunks = [
        {"Hello", 22.78, []},
        {"\u00AD", 3.33, []},
        {"world", 26.11, []}
      ]

      assert Text.wrap_chunks(chunks, 50.0) == {[{"Hello", 22.78, []}, {"world", 26.11, []}], []}

      chunks = [
        {"Hello", 22.78, color: :red},
        {"\u00AD", 3.33, color: :green},
        {"world", 26.11, color: :blue}
      ]

      assert Text.wrap_chunks(chunks, 50.0) ==
               {[{"Hello", 22.78, color: :red}, {"world", 26.11, color: :blue}], []}
    end

    test "it wraps on a soft-hyphen" do
      chunks = [
        {"Hello", 22.78, []},
        {"\u00AD", 3.33, []},
        {"world", 26.11, []}
      ]

      assert Text.wrap_chunks(chunks, 30.0) ==
               {[{"Hello", 22.78, []}, {"\u00AD", 3.33, []}], [{"world", 26.11, []}]}

      chunks = [
        {"Hello", 22.78, size: 10},
        {"\u00AD", 3.33, size: 11},
        {"world", 26.11, size: 12}
      ]

      assert Text.wrap_chunks(chunks, 30.0) ==
               {[{"Hello", 22.78, size: 10}, {"\u00AD", 3.33, size: 11}],
                [{"world", 26.11, size: 12}]}
    end

    test "it wraps on a carriage return" do
      chunks = [
        {"Hello", 22.78, []},
        {"\n", 0.00, []},
        {"world", 26.11, []}
      ]

      assert Text.wrap_chunks(chunks, 60.0) ==
               {[{"Hello", 22.78, []}, {"\n", 0.00, []}], [{"world", 26.11, []}]}

      chunks = [
        {"Hello", 22.78, size: 10},
        {"\n", 0.00, size: 11},
        {"world", 26.11, size: 12}
      ]

      assert Text.wrap_chunks(chunks, 60.0) ==
               {[{"Hello", 22.78, size: 10}, {"\n", 0.00, size: 11}],
                [{"world", 26.11, size: 12}]}
    end

    test "it wraps on a carriage return even if the carriage return is first" do
      chunks = [
        {"\n", 0.00, []},
        {"world", 26.11, []}
      ]

      assert Text.wrap_chunks(chunks, 60.0) == {[{"\n", 0.00, []}], [{"world", 26.11, []}]}

      chunks = [
        {"\n", 0.00, size: 10},
        {"world", 26.11, size: 11}
      ]

      assert Text.wrap_chunks(chunks, 60.0) ==
               {[{"\n", 0.00, size: 10}], [{"world", 26.11, size: 11}]}
    end

    test "it returns an empty array if the next chunk doesn't fit" do
      chunks = [
        {"Hello", 22.78, []},
        {" ", 2.78, []},
        {"world", 26.11, []}
      ]

      assert Text.wrap_chunks(chunks, 20.0) ==
               {[], [{"Hello", 22.78, []}, {" ", 2.78, []}, {"world", 26.11, []}]}

      chunks = [
        {"Hello", 22.78, size: 10},
        {" ", 2.78, size: 11},
        {"world", 26.11, size: 12}
      ]

      assert Text.wrap_chunks(chunks, 20.0) ==
               {[],
                [{"Hello", 22.78, size: 10}, {" ", 2.78, size: 11}, {"world", 26.11, size: 12}]}
    end

    test "it returns all chunks if they fit" do
      chunks = [
        {"Hello", 22.78, []},
        {" ", 2.78, []},
        {"world", 26.11, []}
      ]

      assert Text.wrap_chunks(chunks, 60.0) ==
               {[{"Hello", 22.78, []}, {" ", 2.78, []}, {"world", 26.11, []}], []}

      chunks = [
        {"Hello", 22.78, size: 10},
        {" ", 2.78, size: 11},
        {"world", 26.11, size: 12}
      ]

      assert Text.wrap_chunks(chunks, 60.0) ==
               {[{"Hello", 22.78, size: 10}, {" ", 2.78, size: 11}, {"world", 26.11, size: 12}],
                []}
    end
  end

  # describe "wrap/2" do
  #   test "it breaks on a space", %{font: font, font_size: font_size} do
  #     string = "Hello world"
  #     width = font.text_width("world", font_size)

  #     assert Text.wrap(string, width, font, font_size) == ["Hello", "world"]
  #   end

  #   test "it breaks on a zero-width space", %{font: font, font_size: font_size} do
  #     string = "Hello\u200Bworld"

  #     width = font.text_width("world", font_size)
  #     assert Text.wrap(string, width, font, font_size) == ["Hello", "world"]
  #   end

  #   test "it does not display zero-width space", %{font: font, font_size: font_size} do
  #     string = "Hello\u200Bworld"

  #     width = font.text_width("Hello world", font_size)
  #     assert Text.wrap(string, width, font, font_size) == ["Helloworld"]
  #   end

  #   test "it breaks on a tab", %{font: font, font_size: font_size} do
  #     string = "Hello\tworld"

  #     width = font.text_width("world", font_size)
  #     assert Text.wrap(string, width, font, font_size) == ["Hello", "world"]
  #   end

  #   test "it does not break on a non-breaking space", %{font: font, font_size: font_size} do
  #     string = "Hello\u00A0world"

  #     width = font.text_width("world   ", font_size)
  #     assert Text.wrap(string, width, font, font_size) == ["Hello\u00A0world"]
  #   end

  #   test "it includes words that are longer than the wrapping boundary", %{
  #     font: font,
  #     font_size: font_size
  #   } do
  #     string = "Hello wwwwworld"
  #     width = font.text_width("Hello", font_size)

  #     assert Text.wrap(string, width, font, font_size) == ["Hello", "wwwwworld"]
  #   end

  #   test "It correctly handles the breaking character (drops the appropriate space)", %{
  #     font: font,
  #     font_size: font_size
  #   } do
  #     string = "foo bar baz"
  #     width = font.text_width("foo bar", font_size)

  #     assert Text.wrap(string, width, font, font_size) == ["foo bar", "baz"]
  #   end

  #   test "It force wraps on a charriage return", %{font: font, font_size: font_size} do
  #     string = "foo\nbar baz"
  #     width = font.text_width("bar baz", font_size)

  #     assert Text.wrap(string, width, font, font_size) == ["foo", "bar baz"]
  #   end

  #   test "It force wraps on every charriage return", %{font: font, font_size: font_size} do
  #     string = "foo\n\n\nbar baz"
  #     width = font.text_width("bar baz", font_size)

  #     assert Text.wrap(string, width, font, font_size) == ["foo", "", "", "bar baz"]
  #   end

  #   test "It wraps after a hyphen", %{font: font, font_size: font_size} do
  #     string = "foo bar-baz"
  #     width = font.text_width("foo bar-b", font_size)

  #     assert Text.wrap(string, width, font, font_size) == ["foo bar-", "baz"]
  #   end

  #   test "it does not break after a hyphen that follows white space and precedes a word", %{
  #     font: font,
  #     font_size: font_size
  #   } do
  #     string = "Hello -world"

  #     width = font.text_width("Hello  ", font_size)
  #     assert Text.wrap(string, width, font, font_size) == ["Hello", "-world"]
  #   end

  #   test "it does not break before a hyphen that follows a word", %{
  #     font: font,
  #     font_size: font_size
  #   } do
  #     string = "Hello world-"

  #     width = font.text_width("Hello world", font_size)
  #     assert Text.wrap(string, width, font, font_size) == ["Hello", "world-"]
  #   end

  #   test "it does not break after a hyphen that follows a soft hyphen and precedes a word", %{
  #     font: font,
  #     font_size: font_size
  #   } do
  #     string = "Hello\u00AD-"

  #     width = font.text_width("Hello-", font_size)

  #     assert Text.wrap(string, width, font, font_size) == ["Hello-"]

  #     string = "Hello\u00AD-world"
  #     assert Text.wrap(string, width, font, font_size) == ["Hello\u00AD", "-world"]
  #   end

  #   test "it wraps on a soft hyphen", %{font: font, font_size: font_size} do
  #     string = "Hello\u00ADworld"

  #     width = font.text_width("Hello  ", font_size)
  #     assert Text.wrap(string, width, font, font_size) == ["Hello\u00AD", "world"]
  #   end

  #   test "it removes unused soft-hyphens", %{font: font, font_size: font_size} do
  #     string = "Hello\u00ADworld"

  #     width = font.text_width("Helloworld", font_size)
  #     assert Text.wrap(string, width, font, font_size) == ["Helloworld"]
  #   end
  # end
end
