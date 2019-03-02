defmodule Mail.Parsers.RFC2822 do
  @moduledoc """
  RFC2822 Parser

  Will attempt to parse a valid RFC2822 message back into
  a `%Mail.Message{}` data model.

      Mail.Parsers.RFC2822.parse(message)
      %Mail.Message{body: "Some message", headers: %{to: ["user@example.com"], from: "other@example.com", subject: "Read this!"}}
  """

  @months ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)

  @spec parse(binary() | nonempty_maybe_improper_list()) :: Mail.Message.t()
  def parse(content)

  def parse([_ | _] = lines) do
    [headers, lines] = extract_headers(lines)

    %Mail.Message{}
    |> parse_headers(headers)
    |> mark_multipart
    |> parse_body(lines)
  end

  def parse(content),
    do: content |> String.split("\r\n") |> parse

  defp extract_headers(list, headers \\ [])

  defp extract_headers(["" | tail], headers),
    do: [Enum.reverse(headers), tail]

  defp extract_headers([<<" " <> _>> = folded_body | tail], [previous_header | headers]),
    do: extract_headers(tail, [previous_header <> folded_body | headers])

  defp extract_headers([<<"\t" <> _>> = folded_body | tail], [previous_header | headers]),
    do: extract_headers(tail, [previous_header <> folded_body | headers])

  defp extract_headers([header | tail], headers),
    do: extract_headers(tail, [header | headers])

  @doc """
  Parses a RFC2822 timestamp to an Erlang timestamp

  [RFC2822 3.3 - Date and Time Specification](https://tools.ietf.org/html/rfc2822#section-3.3)

  Timezone information is ignored
  """
  def erl_from_timestamp(<<" ", rest::binary>>), do: erl_from_timestamp(rest)
  def erl_from_timestamp(<<"\t", rest::binary>>), do: erl_from_timestamp(rest)

  def erl_from_timestamp(<<_day::binary-size(3), ", ", rest::binary>>) do
    erl_from_timestamp(rest)
  end

  def erl_from_timestamp(<<date::binary-size(1), " ", rest::binary>>) do
    erl_from_timestamp("0" <> date <> " " <> rest)
  end

  def erl_from_timestamp(
        <<date::binary-size(2), " ", month::binary-size(3), " ", year::binary-size(4), " ",
          hour::binary-size(2), ":", minute::binary-size(2), ":", second::binary-size(2), " ",
          _timezone::binary-size(5), _rest::binary>>
      ) do
    year = year |> String.to_integer()
    month = Enum.find_index(@months, &(&1 == month)) + 1
    date = date |> String.to_integer()

    hour = hour |> String.to_integer()
    minute = minute |> String.to_integer()
    second = second |> String.to_integer()

    {{year, month, date}, {hour, minute, second}}
  end

  # This adds support for a now obsolete format
  # https://tools.ietf.org/html/rfc2822#section-4.3
  def erl_from_timestamp(
        <<date::binary-size(2), " ", month::binary-size(3), " ", year::binary-size(4), " ",
          hour::binary-size(2), ":", minute::binary-size(2), ":", second::binary-size(2), " ",
          timezone::binary-size(3), _rest::binary>>
      ) do
    erl_from_timestamp(
      date <>
        " " <>
        month <>
        " " <> year <> " " <> hour <> ":" <> minute <> ":" <> second <> " (" <> timezone <> ")"
    )
  end

  defp parse_headers(message, []), do: message

  defp parse_headers(message, [header | tail]) do
    [name, body] = String.split(header, ":", parts: 2)
    key = String.downcase(name)
    headers = Map.put(message.headers, key, parse_header_value(name, body))
    message = %{message | headers: headers}
    parse_headers(message, tail)
  end

  defp mark_multipart(message),
    do: Map.put(message, :multipart, multipart?(message.headers))

  defp parse_header_value(key, " " <> value),
    do: parse_header_value(key, value)

  defp parse_header_value(key, "\r" <> value),
    do: parse_header_value(key, value)

  defp parse_header_value(key, "\n" <> value),
    do: parse_header_value(key, value)

  defp parse_header_value(key, "\t" <> value),
    do: parse_header_value(key, value)

  defp parse_header_value("To", value),
    do: parse_recipient_value(value)

  defp parse_header_value("CC", value),
    do: parse_recipient_value(value)

  defp parse_header_value("From", value),
    do:
      parse_recipient_value(value)
      |> List.first()

  defp parse_header_value("Reply-To", value),
    do:
      parse_recipient_value(value)
      |> List.first()

  defp parse_header_value("Date", timestamp),
    do: erl_from_timestamp(timestamp)

  defp parse_header_value("Received", value),
    do: parse_received_value(value)

  defp parse_header_value("Content-Type", value),
    do: parse_structured_header_value(value)

  defp parse_header_value("Content-Disposition", value),
    do: parse_structured_header_value(value)

  defp parse_header_value(_key, value),
    do: value

  defp parse_structured_header_value(value) do
    case String.split(value, ~r/;\s*/) do
      [value | []] -> value
      [value | subtypes] -> [value | parse_header_subtypes(subtypes)]
    end
  end

  defp parse_recipient_value(value) do
    Regex.scan(~r/\s*"?(.*?)"?\s*?<?([^\s]+@[^\s>]+)>?,?/, value)
    |> Enum.map(fn
      [_, "", address] -> address
      [_, name, address] -> {name, address}
    end)
  end

  defp parse_received_value(value) do
    [value | [date]] = String.split(value, ~r/;\s*/)
    [value | [{"date", erl_from_timestamp(date)}]]
  end

  defp parse_header_subtypes([]), do: []

  defp parse_header_subtypes([subtype | tail]) do
    [key, value] = String.split(subtype, "=", parts: 2)
    key = key_to_atom(key)
    [{key, normalize_subtype_value(key, value)} | parse_header_subtypes(tail)]
  end

  defp normalize_subtype_value("boundary", value),
    do: get_boundary(value)

  defp normalize_subtype_value(_key, value),
    do: value

  defp parse_body(%Mail.Message{multipart: true} = message, lines) do
    content_type = message.headers["content-type"]
    boundary = Mail.Proplist.get(content_type, "boundary")

    parts =
      boundary
      |> extract_parts(lines)
      |> Enum.map(fn part ->
        parse(part)
      end)

    Map.put(message, :parts, parts)
  end

  defp parse_body(%Mail.Message{} = message, lines) do
    decoded =
      lines
      |> join_body
      |> decode(message)

    Map.put(message, :body, decoded)
  end

  defp join_body(lines, acc \\ [])
  defp join_body([], acc), do: acc |> Enum.reverse() |> Enum.join("\r\n")
  defp join_body([""], acc), do: acc |> Enum.reverse() |> Enum.join("\r\n")
  defp join_body([head | tail], acc), do: join_body(tail, [head | acc])

  defp extract_parts(boundary, lines, acc \\ [], parts \\ nil)

  defp extract_parts(_boundary, [], _acc, parts),
    do: Enum.reverse(parts)

  defp extract_parts(boundary, ["--" <> boundary | tail], acc, nil),
    do: extract_parts(boundary, tail, acc, [])

  defp extract_parts(boundary, ["--" <> boundary | tail], acc, parts),
    do: extract_parts(boundary, tail, [], [Enum.reverse(acc) | parts])

  defp extract_parts(boundary, [<<"--" <> rest>> = line | tail], acc, parts) do
    if rest == boundary <> "--" do
      extract_parts(boundary, [], [], [Enum.reverse(acc) | parts])
    else
      extract_parts(boundary, tail, [line | acc], parts)
    end
  end

  defp extract_parts(boundary, [_line | tail], acc, nil),
    do: extract_parts(boundary, tail, acc, nil)

  defp extract_parts(boundary, [head | tail], acc, parts),
    do: extract_parts(boundary, tail, [head | acc], parts)

  defp key_to_atom(key),
    do:
      String.downcase(key)
      |> String.replace("-", "_")

  defp multipart?(headers) do
    content_type = headers["content-type"]

    !!case content_type do
      nil -> nil
      type when is_binary(type) -> nil
      content_type -> Mail.Proplist.get(content_type, "boundary")
    end
  end

  defp decode(body, message) do
    body = String.trim_trailing(body)
    transfer_encoding = Mail.Message.get_header(message, "content-transfer-encoding")
    Mail.Encoder.decode(body, transfer_encoding)
  end

  defp get_boundary("\"" <> boundary), do: String.slice(boundary, 0..-2)
  defp get_boundary(boundary), do: boundary
end
