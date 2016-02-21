defmodule Mail.Parsers.RFC2822 do
  @moduledoc """
  RFC2822 Parser

  Will attempt to parse a valid RFC2822 message back into 
  a `%Mail.Message{}` data model.

      Mail.Parsers.RFC2822.parse(message)
      %Mail.Message{body: "Some message", headers: %{to: ["user@example.com"], from: "other@example.com", subject: "Read this!"}}
  """
  def parse(content) do
    matcher = ~r/^(\r\n)?(?<headers>.+?)\r\n\r\n(?<body>.+)/s
    %{"headers" => headers, "body" => body} = Regex.named_captures(matcher, content)

    %Mail.Message{}
    |> parse_headers(headers)
    |> parse_body(body)
  end

  defp parse_headers(message, headers) do
    headers = String.split(headers, ~r/\r\n(?!\s+)/s)
      |> Enum.map(&(String.split(&1, ": ", parts: 2)))
      |> Enum.into(%{}, fn([key, value]) ->
        {key_to_atom(key), parse_header_value(key, value)}
      end)

    Map.put(message, :headers, headers)
    |> Map.put(:multipart, multipart?(headers))
  end

  defp parse_header_value("To", value),
    do: parse_recipient_value(value)
  defp parse_header_value("CC", value),
    do: parse_recipient_value(value)
  defp parse_header_value("From", value),
    do: parse_recipient_value(value)
        |> List.first()

  defp parse_header_value(_key, value) do
    case String.split(value, ~r/;\s+/) do
      [value | []] -> value
      [value | subtypes] -> [value | parse_header_subtypes(subtypes)]
    end
  end

  defp parse_recipient_value(value) do
    String.split(value, ", ")
    |> Enum.map(fn(recipient) ->
      case String.split(recipient, ~r/\s(?!.*\s)/) do
        [name, address] ->
          %{"address" => address} = Regex.named_captures(~r/<(?<address>.+)>/, address)
          {name, address}
        [address] -> address
      end
    end)
  end

  defp parse_header_subtypes([]), do: []
  defp parse_header_subtypes([subtype | tail]) do
    [key, value] = String.split(subtype, "=")
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
  defp get_boundary(boundary) do
    Regex.run(~r/"(.+)"/, boundary)
    |> List.last()
  end
end
