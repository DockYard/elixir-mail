defmodule Mail.Parsers.RFC2822 do
  @moduledoc """
  RFC2822 Parser

  Will attempt to parse a valid RFC2822 message back into
  a `%Mail.Message{}` data model.

      Mail.Parsers.RFC2822.parse(message)
      %Mail.Message{body: "Some message", headers: %{to: ["user@example.com"], from: "other@example.com", subject: "Read this!"}}
  """

  @months ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)

  def parse(content) do
    matcher = ~r/^(\r\n)?(?<headers>.+?)\r\n\r\n(?<body>.*)/s
    %{"headers" => headers, "body" => body} = Regex.named_captures(matcher, content)

    %Mail.Message{}
    |> parse_headers(headers)
    |> parse_body(body)
  end


  @doc """
  Parses a RFC2822 timestamp to an Erlang timestamp

  [RFC2822 3.3 - Date and Time Specification](https://tools.ietf.org/html/rfc2822#section-3.3)

  Timezone information is ignored
  """
  def erl_from_timestamp(timestamp) do
    regex = ~r/(\w{3},\s+)?(?<day>\d{1,2})\s+(?<month>\w{3})\s+(?<year>\d{4})\s+(?<hour>\d{2}):(?<minute>\d{2}):(?<second>\d{2})/
    capture = Regex.named_captures(regex, timestamp)

    year  = capture["year"] |> String.to_integer()
    month = Enum.find_index(@months, &(&1 == capture["month"])) + 1
    day   = capture["day"] |> String.to_integer()

    hour   = capture["hour"] |> String.to_integer()
    minute = capture["minute"] |> String.to_integer()
    second = capture["second"] |> String.to_integer()

    {{year, month, day}, {hour, minute, second}}
  end

  defp parse_headers(message, headers) do
    headers = String.split(headers, ~r/\r\n(?!\s+)/s)
      |> Enum.map(&(String.split(&1, ":", parts: 2)))
      |> Enum.into(%{}, fn([key, value]) ->
        {key_to_atom(key), parse_header_value(key, value)}
      end)

    Map.put(message, :headers, headers)
    |> Map.put(:multipart, multipart?(headers))
  end

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
    do: parse_recipient_value(value)
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
    case String.split(value, ~r/;\s+/) do
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
    [value | [date]] = String.split(value, ~r/;\s+/)
    [value | [date: erl_from_timestamp(date)]]
  end

  defp parse_header_subtypes([]), do: []
  defp parse_header_subtypes([subtype | tail]) do
    [key, value] = String.split(subtype, "=", parts: 2)
    key = key_to_atom(key)
    [{key, normalize_subtype_value(key, value)} | parse_header_subtypes(tail)]
  end

  defp normalize_subtype_value(:boundary, value),
    do: get_boundary(value)
  defp normalize_subtype_value(_key, value),
    do: value

  defp parse_body(%Mail.Message{multipart: true} = message, body) do
    boundary = get_in(message.headers, [:content_type, :boundary])

    parts =
      Regex.run(~r/--#{boundary}?(.+)--#{boundary}--/s, body)
      |> List.last()
      |> String.split("--#{boundary}")
      |> Enum.map(&(parse(&1)))

    Map.put(message, :parts, parts)
  end
  defp parse_body(%Mail.Message{} = message, body),
    do: Map.put(message, :body, decode(body, message))

  defp key_to_atom(key),
    do: String.downcase(key)
        |> String.replace("-", "_")
        |> String.to_atom()

  defp multipart?(headers) do
    !!(case get_in(headers, [:content_type]) do
      nil -> nil
      type when is_binary(type) -> nil
      content_type -> content_type[:boundary]
    end)
  end

  defp decode(body, message) do
    body = String.rstrip(body)

    Mail.Encoder.decode(body, get_in(message.headers, [:content_transfer_encoding]))
  end

  defp get_boundary(nil), do: nil
  defp get_boundary("\"" <> boundary), do: String.slice(boundary, 0..-2)
  defp get_boundary(boundary), do: boundary
end
