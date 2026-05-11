defmodule Mail.Renderers.RFC2822.HeaderEncodingTest do
  use ExUnit.Case, async: true

  alias Mail.Renderers.RFC2822.HeaderEncoding

  describe "Physical folding (RFC 5322 obs-fold), ASCII-only unstructured" do
    test "short value stays on one line" do
      assert "Hello World" == HeaderEncoding.fold("Hello World", 9)
    end

    test "long value with spaces folds only at foldable whitespace" do
      value =
        "lorem ipsum dolor sit amet consectetur adipiscing elit sed do " <>
          "eiusmod tempor incididunt ut labore et dolore magna aliqua"

      assert "lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod" <>
               "" <> "\r\n " <> "" <> "tempor incididunt ut labore et dolore magna aliqua" =
               HeaderEncoding.fold(value, 9)
    end

    test "tabs are valid fold whitespace and become the continuation indent" do
      value =
        Enum.join(
          ~w(alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron pi rho),
          "\t"
        )

      assert "alpha\tbeta\tgamma\tdelta\tepsilon\tzeta\teta\ttheta\tiota\tkappa\tlambda\tmu\tnu" <>
               "\r\n" <> "\txi\tomicron\tpi\trho" = folded = HeaderEncoding.fold(value, 9)

      assert %Mail.Message{headers: %{"subject" => ^value}} =
               Mail.Parsers.RFC2822.parse("Subject: " <> folded <> "\r\n\r\n")
    end

    test "consecutive whitespace runs are preserved verbatim when unfolded" do
      value = "first  second  third  fourth  fifth  sixth  seventh  eighth  ninth  tenth"

      assert "first  second  third  fourth  fifth  sixth  seventh  eighth  ninth" <>
               "\r\n" <> "  tenth" =
               folded = HeaderEncoding.fold(value, 9)

      header = "Subject: " <> folded <> "\r\n\r\n"

      assert %Mail.Message{headers: %{"subject" => ^value}} =
               Mail.Parsers.RFC2822.parse(header)
    end

    test "long header name uses the actual prefix length when folding" do
      value = "alpha beta gamma delta epsilon zeta eta theta iota kappa"
      prefix = "X-Long-Custom-Header-Name: "
      prefix_len = byte_size(prefix)

      assert "alpha beta gamma delta epsilon zeta eta theta iota" <>
               "\r\n" <> " kappa" = folded = HeaderEncoding.fold(value, prefix_len)

      assert %Mail.Message{headers: %{"x-long-custom-header-name" => ^value}} =
               Mail.Parsers.RFC2822.parse(prefix <> folded <> "\r\n\r\n")
    end

    test "a single unbreakable ASCII token longer than max overflows" do
      # No WSP in the value, so no fold point exists — the line is allowed
      # to exceed 78 octets rather than splitting an indivisible token.
      value = String.duplicate("a", 100)
      assert value == HeaderEncoding.fold(value, 9)
    end
  end

  describe "RFC 2047 Q encoding and word boundaries" do
    test "single non-ASCII grapheme produces one encoded-word" do
      encoded = HeaderEncoding.encode("hi 😀")
      assert encoded == "=?UTF-8?Q?hi_=F0=9F=98=80?="
      assert byte_size(encoded) <= 75
    end

    test "em-dash regression — all UTF-8 bytes of `–` stay in one word" do
      # Reproduces the regression from RFC 2047 §5(3) described in the plan:
      # the em-dash's three octets =E2=80=93 must not be split between two
      # adjacent encoded-words.
      input = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx em-dash follows: – other text"

      assert "=?UTF-8?Q?xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx_em-dash_follows:_?= =?UTF-8?Q?=E2=80=93_other_text?=" ==
               HeaderEncoding.encode(input)
    end

    test "a single oversized grapheme cluster raises" do
      # 256 ZWJ-separated emoji combine into one extended grapheme cluster
      # whose Q-encoded form (4 octets per emoji + 6 for each ZWJ, all
      # =HH-escaped) easily exceeds the 63-byte payload limit.
      oversized = Enum.map_join(1..16, "\u200D", fn _ -> "👨" end)

      assert_raise ArgumentError, ~r/exceeds the RFC 2047 maximum/, fn ->
        HeaderEncoding.encode(oversized)
      end
    end

    test "long non-ASCII run produces multiple encoded-words separated by SPACE" do
      input = String.duplicate("über ", 30)
      encoded = HeaderEncoding.encode(input)
      words = String.split(encoded, " ")

      assert [
               "=?UTF-8?Q?=C3=BCber_=C3=BCber_=C3=BCber_=C3=BCber_=C3=BCber_=C3=BCber_?=",
               "=?UTF-8?Q?=C3=BCber_=C3=BCber_=C3=BCber_=C3=BCber_=C3=BCber_=C3=BCber_?=",
               "=?UTF-8?Q?=C3=BCber_=C3=BCber_=C3=BCber_=C3=BCber_=C3=BCber_=C3=BCber_?=",
               "=?UTF-8?Q?=C3=BCber_=C3=BCber_=C3=BCber_=C3=BCber_=C3=BCber_=C3=BCber_?=",
               "=?UTF-8?Q?=C3=BCber_=C3=BCber_=C3=BCber_=C3=BCber_=C3=BCber_=C3=BCber_?="
             ] == words
    end

    test "spaces inside the encoded text become `_` and round-trip to spaces" do
      input = "Café résumé"
      encoded = HeaderEncoding.encode(input)
      assert encoded == "=?UTF-8?Q?Caf=C3=A9_r=C3=A9sum=C3=A9?="

      header = "Subject: " <> encoded <> "\r\n\r\n"

      assert %Mail.Message{headers: %{"subject" => ^input}} =
               Mail.Parsers.RFC2822.parse(header)
    end

    test "pure ASCII strings pass through unchanged" do
      text = "Hello World!"
      assert text == HeaderEncoding.encode(text)
      text = "plain text 1234 ?@#$%"
      assert text == HeaderEncoding.encode(text)
    end

    test "literal `?`, `=`, `_` and control octets are Q-encoded" do
      assert HeaderEncoding.encode("ü?=_\t") == "=?UTF-8?Q?=C3=BC=3F=3D=5F=09?="
    end
  end

  describe "Folding interaction with encoded-words" do
    test "long encoded value folds between encoded-words, never inside one" do
      input = String.duplicate("über ", 30)
      encoded = HeaderEncoding.encode_for_prefix(input, 9)

      assert "=?UTF-8?Q?=C3=BCber_=C3=BCber_=C3=BCber_=C3=BCber_=C3=BCber_=C3=BCb?=" <>
               "\r\n " <>
               "=?UTF-8?Q?er_=C3=BCber_=C3=BCber_=C3=BCber_=C3=BCber_=C3=BCber_=C3=BCber_?=" <>
               "\r\n " <>
               "=?UTF-8?Q?=C3=BCber_=C3=BCber_=C3=BCber_=C3=BCber_=C3=BCber_=C3=BCber_?=" <>
               "\r\n " <>
               "=?UTF-8?Q?=C3=BCber_=C3=BCber_=C3=BCber_=C3=BCber_=C3=BCber_=C3=BCber_?=" <>
               "\r\n " <>
               "=?UTF-8?Q?=C3=BCber_=C3=BCber_=C3=BCber_=C3=BCber_=C3=BCber_=C3=BCber_?=" ==
               HeaderEncoding.fold(encoded, 9)
    end

    test "a value that fills the first line to exactly 78 octets needs no fold" do
      # 78 - 9 (prefix "Subject: ") = 69 bytes of content fits without folding.
      value = String.duplicate("a", 69)
      folded = HeaderEncoding.fold(value, 9)
      assert folded == value
      assert byte_size("Subject: " <> folded) == 78
    end

    test "embedded LF in the value is preserved via Q-encoding and round-trips" do
      input = "line one\nline two with über content"

      header =
        Mail.build()
        |> Mail.put_subject(input)
        |> Mail.render()

      assert %Mail.Message{headers: %{"subject" => ^input}} =
               Mail.Parsers.RFC2822.parse(header)
    end
  end

  describe "needs_encoding?/1" do
    test "false for pure ASCII printable + tab" do
      refute HeaderEncoding.needs_encoding?("hello world")
      refute HeaderEncoding.needs_encoding?("tab\there")
      refute HeaderEncoding.needs_encoding?("special chars ?=_,.;:<>@")
    end

    test "true for non-ASCII or control octets" do
      assert HeaderEncoding.needs_encoding?("über")
      assert HeaderEncoding.needs_encoding?("with\nLF")
      assert HeaderEncoding.needs_encoding?("with\rCR")
      assert HeaderEncoding.needs_encoding?("emoji 😀")
    end
  end
end
