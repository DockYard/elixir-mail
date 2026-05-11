defmodule Mail.Renderers.RFC2822.HeaderEncoding do
  @moduledoc """
  RFC 2047 encoded-word generation and RFC 5322 header folding.

  This module is used by `Mail.Renderers.RFC2822` to turn header values into
  spec-compliant physical lines:

    * Non-ASCII values are encoded as one or more `=?UTF-8?Q?...?=` words,
      split on grapheme cluster boundaries so a multi-octet character can
      never span two encoded-words (RFC 2047 §5.3).
    * Adjacent encoded-words are separated by linear white space so that the
      folding pass can later replace it with `CRLF SPACE` (RFC 2047 §2/§5).
    * Spaces inside an encoded-word are written as `_` (RFC 2047 §4.2) so
      the entire word stays an indivisible token to the folder.
    * Folding inserts `CRLF` before foldable whitespace whenever the next
      atom would push a physical line past 78 octets (RFC 5322 §2.1.1).
      Encoded-words are never split.
  """

  @ew_charset "UTF-8"
  @ew_encoding "Q"
  @ew_prefix "=?" <> @ew_charset <> "?" <> @ew_encoding <> "?"
  @ew_suffix "?="

  # RFC 2047 §2: the whole encoded-word (including delimiters) must be <= 75 octets.
  @rfc2047_max_word_length 75
  @ew_overhead byte_size(@ew_prefix) + byte_size(@ew_suffix)
  @ew_max_payload @rfc2047_max_word_length - @ew_overhead

  # RFC 5322 §2.1.1: lines SHOULD be <= 78 characters (excluding CRLF).
  @max_line_length 78

  @doc """
  Encodes `value` per RFC 2047, sizing the first encoded-word so it fits on
  the same physical line as a header-name prefix of `prefix_len` octets, and
  sizing subsequent encoded-words so they fit on continuation lines.

  Pure ASCII values are returned unchanged.
  """
  @spec encode_for_prefix(binary(), non_neg_integer()) :: binary()
  def encode_for_prefix(value, prefix_len) when is_binary(value) do
    if needs_encoding?(value) do
      encode(value, max(@max_line_length - prefix_len - @ew_overhead, 1))
    else
      value
    end
  end

  @doc """
  Returns `true` if `value` contains any octet that is not allowed unencoded in
  an RFC 5322 header field (i.e. anything outside the printable ASCII range
  plus horizontal tab).
  """
  @spec needs_encoding?(binary()) :: boolean()
  def needs_encoding?(<<>>), do: false
  def needs_encoding?(<<?\t, rest::binary>>), do: needs_encoding?(rest)
  def needs_encoding?(<<b, rest::binary>>) when b in 0x20..0x7E, do: needs_encoding?(rest)
  def needs_encoding?(<<_, _::binary>>), do: true

  @doc """
  Encodes a string as one or more RFC 2047 Q encoded-words when it contains
  characters that require encoding. Pure ASCII strings are returned unchanged.

  Multiple encoded-words are joined by a single SPACE, which is the linear
  white space mandated between adjacent encoded-words by RFC 2047. The folder
  may later replace that SPACE with `CRLF SPACE`.

  Encoded-words are split on extended grapheme cluster boundaries so a
  multi-octet character (including ZWJ sequences) is never divided across two
  words. If a single grapheme's Q-encoded form is larger than will fit in one
  encoded-word, `ArgumentError` is raised.

  `first_word_payload` constrains the Q-encoded payload of the first word.
  Use it when the first physical line must accommodate a header-name prefix
  (see `encode_for_prefix/2`). Every subsequent word is sized at the standard
  RFC 2047 maximum of 63 payload octets.
  """
  @spec encode(binary(), pos_integer()) :: binary()
  def encode(value, first_word_payload \\ @ew_max_payload) when is_binary(value) do
    if needs_encoding?(value) do
      first_max = clamp_payload(first_word_payload)

      value
      |> String.graphemes()
      |> pack_words(first_max, @ew_max_payload, [], <<>>)
      |> wrap_words()
    else
      value
    end
  end

  defp clamp_payload(n) when is_integer(n) and n >= 1, do: min(n, @ew_max_payload)
  defp clamp_payload(_), do: @ew_max_payload

  defp pack_words([], _first, _rest, words, <<>>), do: Enum.reverse(words)
  defp pack_words([], _first, _rest, words, acc), do: Enum.reverse([acc | words])

  defp pack_words([grapheme | rest], first_max, rest_max, words, acc) do
    encoded = q_encode_grapheme(grapheme)
    size = byte_size(encoded)
    current_max = if words == [], do: first_max, else: rest_max

    cond do
      size > rest_max ->
        raise ArgumentError,
              "grapheme cluster #{inspect(grapheme)} encodes to #{size} bytes, " <>
                "which exceeds the RFC 2047 maximum encoded-word payload of " <>
                "#{rest_max} bytes"

      byte_size(acc) + size <= current_max ->
        pack_words(rest, first_max, rest_max, words, <<acc::binary, encoded::binary>>)

      byte_size(acc) == 0 ->
        # `current_max` is tighter than `rest_max`; the first word cannot fit
        # even a single grapheme. Skip the constrained first word and let
        # this grapheme become the start of the next (full-sized) word. The
        # caller's first physical line will overflow by a small amount, which
        # is the documented degraded case for unsplittable atoms.
        pack_words(rest, rest_max, rest_max, words, encoded)

      true ->
        pack_words(rest, first_max, rest_max, [acc | words], encoded)
    end
  end

  defp q_encode_grapheme(grapheme) when is_binary(grapheme) do
    for <<byte <- grapheme>>, into: <<>>, do: q_encode_byte(byte)
  end

  # RFC 2047 §4.2: SPACE may be represented as "_".
  defp q_encode_byte(?\s), do: "_"
  # RFC 2047 §4.2: "=", "?", and "_" must always be encoded.
  defp q_encode_byte(b) when b in [?=, ??, ?_], do: encode_hex(b)
  # Other printable ASCII may be represented verbatim.
  defp q_encode_byte(b) when b in 0x21..0x7E, do: <<b>>
  defp q_encode_byte(b), do: encode_hex(b)

  defp encode_hex(b), do: "=" <> Base.encode16(<<b>>)

  defp wrap_words([]), do: <<>>

  defp wrap_words(payloads) do
    payloads
    |> Enum.map(fn payload -> @ew_prefix <> payload <> @ew_suffix end)
    |> Enum.intersperse(" ")
    |> IO.iodata_to_binary()
  end

  @doc """
  Folds a logical header value into physical lines of at most 78 octets
  (excluding CRLF), per RFC 5322 §2.1.1.

  The first physical line is assumed to begin with a key prefix of length
  `prefix_len` (commonly `byte_size("Subject: ")` for the Subject header).
  Continuation lines start with the foldable whitespace that was already
  present at the fold point.

  Folding only occurs at runs of `SP` or `HT` outside of `=?...?=` tokens. If
  the next atom would overflow the line and no foldable whitespace is
  available on the current line, the line is allowed to overflow rather than
  splitting an indivisible token.
  """
  @spec fold(binary(), non_neg_integer()) :: binary()
  def fold(value, prefix_len) when is_binary(value) do
    value
    |> tokenize()
    |> place_tokens(prefix_len, @max_line_length)
    |> emit()
  end

  defp tokenize(<<>>), do: []

  defp tokenize(value) do
    ~r/[ \t]+|[^ \t]+/
    |> Regex.scan(value)
    |> Enum.map(fn [run] ->
      case run do
        <<b, _::binary>> when b in [?\s, ?\t] -> {:wsp, run}
        _ -> {:text, run}
      end
    end)
  end

  defp place_tokens(tokens, prefix_len, max) do
    initial = %{
      current: [],
      current_count: prefix_len,
      completed: [],
      last_wsp_pos: nil
    }

    state = Enum.reduce(tokens, initial, &place_token(&1, &2, max))
    Enum.reverse([state.current | state.completed])
  end

  defp place_token({:wsp, ws} = token, %{current: current, current_count: count} = st, max) do
    proposed = count + byte_size(ws)

    if proposed > max and current != [] do
      %{
        st
        | current: [token],
          current_count: byte_size(ws),
          completed: [current | st.completed],
          last_wsp_pos: nil
      }
    else
      new_current = current ++ [token]

      %{
        st
        | current: new_current,
          current_count: proposed,
          last_wsp_pos: length(new_current)
      }
    end
  end

  defp place_token({:text, text} = token, %{current: current, current_count: count} = st, max) do
    proposed = count + byte_size(text)

    cond do
      proposed <= max ->
        %{st | current: current ++ [token], current_count: proposed}

      st.last_wsp_pos != nil ->
        pos = st.last_wsp_pos - 1
        before_fold = Enum.take(current, pos)
        after_fold = Enum.drop(current, pos)

        new_state = %{
          st
          | current: after_fold,
            current_count: total_bytes(after_fold),
            completed: [before_fold | st.completed],
            last_wsp_pos: nil
        }

        place_token(token, new_state, max)

      true ->
        %{st | current: current ++ [token], current_count: proposed}
    end
  end

  defp total_bytes(tokens) do
    Enum.reduce(tokens, 0, fn {_, bin}, acc -> acc + byte_size(bin) end)
  end

  defp emit(lines) do
    lines
    |> Enum.map(fn tokens ->
      tokens
      |> Enum.map(fn {_, bin} -> bin end)
      |> IO.iodata_to_binary()
    end)
    |> Enum.join("\r\n")
  end
end
