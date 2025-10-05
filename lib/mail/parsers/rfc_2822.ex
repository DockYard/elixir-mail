defmodule Mail.Parsers.RFC2822 do
  @moduledoc ~S"""
  RFC2822 Parser

  Will attempt to parse a valid RFC2822 message back into
  a `%Mail.Message{}` data model.

  ## Examples

      iex> message = \"""
      ...> To: user@example.com\r
      ...> From: me@example.com\r
      ...> Subject: Test Email\r
      ...> Content-Type: text/plain; foo=bar;\r
      ...>   baz=qux;\r
      ...> \r
      ...> This is the body!\r
      ...> It has more than one line\r
      ...> \"""
      iex> Mail.Parsers.RFC2822.parse(message)
      %Mail.Message{body: "This is the body!\r\nIt has more than one line", headers: %{"to" => ["user@example.com"], "from" => "me@example.com", "subject" => "Test Email", "content-type" => ["text/plain", {"foo", "bar"}, {"baz", "qux"}]}}
  """

  @months ~w(jan feb mar apr may jun jul aug sep oct nov dec)

  @long_months %{
    "january" => "jan",
    "february" => "feb",
    "march" => "mar",
    "april" => "apr",
    "may" => "may",
    "june" => "jun",
    "july" => "jul",
    "august" => "aug",
    "september" => "sep",
    "october" => "oct",
    "november" => "nov",
    "december" => "dec"
  }

  @doc """
  Parses a RFC2822 message back into a `%Mail.Message{}` data model.

  ## Options

    * `:charset_handler` - A function that takes a charset and binary and returns a binary. Defaults to return the string as is.
    * `:header_only` - Whether to parse only the headers. Defaults to false.
    * `:max_part_size` - The maximum size of a part in bytes. Defaults to 10MB.
    * `:skip_large_parts?` - Whether to skip parts larger than `max_part_size`. Defaults to false.

  """
  @spec parse(binary() | nonempty_maybe_improper_list(), keyword()) :: Mail.Message.t()
  def parse(content, opts \\ []) when is_binary(content) do
    {headers, body_offset, has_body} = extract_headers_and_body_offset(content)

    message =
      %Mail.Message{}
      |> parse_headers(headers, opts)
      |> mark_multipart()

    if has_body and not Keyword.get(opts, :header_only, false) do
      # Extract body portion using offset
      body_content =
        if body_offset < byte_size(content) do
          binary_part(content, body_offset, byte_size(content) - body_offset)
        else
          ""
        end

      parse_body_binary(message, body_content, opts)
    else
      message
    end
  end

  defp extract_headers_and_body_offset(content) do
    content
    |> Stream.unfold(fn remaining ->
      case remaining |> :binary.split("\n") do
        [""] -> nil
        [line, rest] -> {{line, byte_size(line) + 1}, rest}
        [line] -> {{line, byte_size(line)}, ""}
      end
    end)
    |> Stream.map(fn {line, size} -> {String.trim_trailing(line), size} end)
    |> Enum.reduce_while({[], nil, 0, false}, &accumulate_headers/2)
    |> case do
      {headers, current_header, offset, false} ->
        # No empty line found - all content is headers, no body section
        headers = if current_header, do: [current_header | headers], else: headers
        {Enum.reverse(headers), offset, false}

      {headers, _current_header, offset, true} ->
        # Empty line found normally - there is a body section (even if empty)
        {headers, offset, true}
    end
  end

  # Empty line marks end of headers
  defp accumulate_headers({"", line_size}, {headers, current_header, offset, _found}) do
    final_headers = if current_header, do: [current_header | headers], else: headers
    {:halt, {Enum.reverse(final_headers), nil, offset + line_size, true}}
  end

  # Folded header (continuation line starts with space or tab)
  defp accumulate_headers(
         {<<first_char, _::binary>> = line, line_size},
         {headers, current_header, offset, found}
       )
       when first_char in [?\s, ?\t] do
    current_header = if current_header, do: current_header <> line, else: nil
    {:cont, {headers, current_header, offset + line_size, found}}
  end

  # New header line
  defp accumulate_headers({line, line_size}, {headers, current_header, offset, found}) do
    new_headers = if current_header, do: [current_header | headers], else: headers
    {:cont, {new_headers, line, offset + line_size, found}}
  end

  @doc """
  Parses a RFC2822 timestamp to a DateTime with timezone

  [RFC2822 3.3 - Date and Time Specification](https://tools.ietf.org/html/rfc2822#section-3.3)

  Also supports obsolete format described in [RFC2822 4.3](https://datatracker.ietf.org/doc/html/rfc2822#section-4.3)
  and invalid timestamps encountered in the wild. The return value will be either a UTC DateTime, or an error tuple
  returning the invalid date string.
  """
  @spec to_datetime(binary()) :: DateTime.t() | {:error, binary()}
  def to_datetime(date_string) do
    parse_datetime(date_string)
  rescue
    _ -> {:error, date_string}
  end

  defp parse_datetime(<<" ", rest::binary>>), do: parse_datetime(rest)
  defp parse_datetime(<<"\t", rest::binary>>), do: parse_datetime(rest)
  defp parse_datetime(<<_day::binary-size(3), ", ", rest::binary>>), do: parse_datetime(rest)

  # Handle day name with space before comma: "Fri , 18 Apr 2025 05:50:01 +0200"
  defp parse_datetime(<<_day::binary-size(3), " ", ",", rest::binary>>), do: parse_datetime(rest)

  defp parse_datetime(<<date::binary-size(1), " ", rest::binary>>),
    do: parse_datetime("0" <> date <> " " <> rest)

  # This caters for an invalid date with no 0 before the hour, e.g. 5:21:43 instead of 05:21:43
  defp parse_datetime(<<date::binary-size(11), " ", hour::binary-size(1), ":", rest::binary>>) do
    parse_datetime("#{date} 0#{hour}:#{rest}")
  end

  # This caters for an invalid date with dashes between the date/month/year parts
  defp parse_datetime(
         <<date::binary-size(2), "-", month::binary-size(3), "-", year::binary-size(4),
           rest::binary>>
       ) do
    parse_datetime("#{date} #{month} #{year}#{rest}")
  end

  # This caters for an invalid two-digit year
  defp parse_datetime(
         <<date::binary-size(2), " ", month::binary-size(3), " ", year::binary-size(2), " ",
           rest::binary>>
       ) do
    year = year |> String.to_integer() |> to_four_digit_year()
    parse_datetime("#{date} #{month} #{year} #{rest}")
  end

  # This caters for missing seconds
  defp parse_datetime(
         <<date::binary-size(11), " ", hour::binary-size(2), ":", minute::binary-size(2), " ",
           rest::binary>>
       ) do
    parse_datetime("#{date} #{hour}:#{minute}:00 #{rest}")
  end

  # Fixes invalid value: Wed, 14 10 2015 12:34:17
  defp parse_datetime(
         <<date::binary-size(2), " ", month_digits::binary-size(2), " ", year::binary-size(4),
           " ", hour::binary-size(2), ":", minute::binary-size(2), ":", second::binary-size(2),
           rest::binary>>
       ) do
    month_name = get_month_name(month_digits)
    parse_datetime("#{date} #{month_name} #{year} #{hour}:#{minute}:#{second}#{rest}")
  end

  defp parse_datetime(
         <<date::binary-size(2), " ", month::binary-size(3), " ", year::binary-size(4), " ",
           hour::binary-size(2), ":", minute::binary-size(2), ":", second::binary-size(2), " ",
           time_zone::binary>>
       ) do
    year = year |> String.to_integer()
    month = get_month(String.downcase(month))
    date = date |> String.to_integer()

    hour = hour |> String.to_integer()
    minute = minute |> String.to_integer()
    second = second |> String.to_integer()

    time_zone = parse_time_zone(time_zone)

    date_string =
      "#{year}-#{date_pad(month)}-#{date_pad(date)}T#{date_pad(hour)}:#{date_pad(minute)}:#{date_pad(second)}#{time_zone}"

    {:ok, datetime, _offset} = DateTime.from_iso8601(date_string)
    datetime
  end

  # This adds support for a now obsolete format
  # https://tools.ietf.org/html/rfc2822#section-4.3
  defp parse_datetime(
         <<date::binary-size(2), " ", month::binary-size(3), " ", year::binary-size(4), " ",
           hour::binary-size(2), ":", minute::binary-size(2), ":", second::binary-size(2), " ",
           timezone::binary-size(3), _rest::binary>>
       ) do
    parse_datetime("#{date} #{month} #{year} #{hour}:#{minute}:#{second} (#{timezone})")
  end

  # Fixes invalid value: Tue Aug 8 12:05:31 CAT 2017
  defp parse_datetime(
         <<month::binary-size(3), " ", date::binary-size(2), " ", hour::binary-size(2), ":",
           minute::binary-size(2), ":", second::binary-size(2), " ", _tz::binary-size(3), " ",
           year::binary-size(4), _rest::binary>>
       ) do
    parse_datetime("#{date} #{month} #{year} #{hour}:#{minute}:#{second}")
  end

  # Fixes invalid value with milliseconds Tue, 20 Jun 2017 09:44:58.568 +0000 (UTC)
  defp parse_datetime(
         <<date::binary-size(2), " ", month::binary-size(3), " ", year::binary-size(4), " ",
           hour::binary-size(2), ":", minute::binary-size(2), ":", second::binary-size(2), ".",
           _milliseconds::binary-size(3), rest::binary>>
       ) do
    parse_datetime("#{date} #{month} #{year} #{hour}:#{minute}:#{second}#{rest}")
  end

  # Fixes invalid value: Tue May 30 15:29:15 2017
  defp parse_datetime(
         <<month::binary-size(3), " ", date::binary-size(2), " ", hour::binary-size(2), ":",
           minute::binary-size(2), ":", second::binary-size(2), " ", year::binary-size(4),
           _rest::binary>>
       ) do
    parse_datetime("#{date} #{month} #{year} #{hour}:#{minute}:#{second} +0000")
  end

  # Fixes invalid value: Tue Aug 8 12:05:31 2017
  defp parse_datetime(
         <<month::binary-size(3), " ", date::binary-size(1), " ", hour::binary-size(2), ":",
           minute::binary-size(2), ":", second::binary-size(2), " ", year::binary-size(4),
           _rest::binary>>
       ) do
    parse_datetime("#{date} #{month} #{year} #{hour}:#{minute}:#{second} +0000")
  end

  # Fixes missing time zone
  defp parse_datetime(
         <<date::binary-size(2), " ", month::binary-size(3), " ", year::binary-size(4), " ",
           hour::binary-size(2), ":", minute::binary-size(2), ":", second::binary-size(2),
           _rest::binary>>
       ) do
    parse_datetime("#{date} #{month} #{year} #{hour}:#{minute}:#{second} +0000")
  end

  # Fixes invalid value with long months: 13 September 2024 18:29:58 +0000
  lm_sizes = Map.keys(@long_months) |> Enum.map(&byte_size/1) |> Enum.uniq()

  for month_size <- lm_sizes do
    defp parse_datetime(
           <<date::binary-size(2), " ", long_month::binary-size(unquote(month_size)), " ",
             year::binary-size(4), " ", hour::binary-size(2), ":", minute::binary-size(2), ":",
             second::binary-size(2), rest::binary>>
         ) do
      month = long_month |> String.downcase() |> get_month_name()
      parse_datetime("#{date} #{month} #{year} #{hour}:#{minute}:#{second}#{rest}")
    end
  end

  # Chop off the day name
  defp parse_datetime(<<_day_name::binary-size(3), " ", rest::binary>>) do
    parse_datetime(rest)
  end

  # Chop off the day name followed by a comma
  defp parse_datetime(<<_day_name::binary-size(3), ", ", rest::binary>>) do
    parse_datetime(rest)
  end

  defp parse_datetime(invalid_datetime), do: {:error, invalid_datetime}

  defp to_four_digit_year(year) when year >= 0 and year < 50, do: 2000 + year
  defp to_four_digit_year(year) when year < 100 and year >= 50, do: 1900 + year

  defp date_pad(number) when number < 10, do: "0" <> Integer.to_string(number)
  defp date_pad(number), do: Integer.to_string(number)

  defp parse_time_zone(<<"(", time_zone::binary>>) do
    time_zone
    |> String.trim_trailing(")")
    |> parse_time_zone()
  end

  for {long_name, short_name} <- @long_months do
    defp get_month_name(unquote(long_name)), do: unquote(short_name)
  end

  @months
  |> Enum.with_index(1)
  |> Enum.each(fn {month_name, month_number} ->
    defp get_month(unquote(month_name)), do: unquote(month_number)

    defp get_month_name(unquote(String.pad_leading(to_string(month_number), 2, "0"))),
      do: unquote(month_name)
  end)

  # Greenwich Mean Time
  defp parse_time_zone("GMT"), do: "+0000"
  # Universal Time
  defp parse_time_zone("UTC"), do: "+0000"
  defp parse_time_zone("UT"), do: "+0000"

  # US
  defp parse_time_zone("EDT"), do: "-0400"
  defp parse_time_zone("EST"), do: "-0500"
  defp parse_time_zone("CDT"), do: "-0500"
  defp parse_time_zone("CST"), do: "-0600"
  defp parse_time_zone("MDT"), do: "-0600"
  defp parse_time_zone("MST"), do: "-0700"
  defp parse_time_zone("PDT"), do: "-0700"
  defp parse_time_zone("PST"), do: "-0800"
  # Military A-Z
  defp parse_time_zone(<<_zone_letter::binary-size(1)>>), do: "-0000"

  defp parse_time_zone(<<"+", offset::binary-size(4), _rest::binary>>), do: "+#{offset}"
  defp parse_time_zone(<<"-", offset::binary-size(4), _rest::binary>>), do: "-#{offset}"

  # Using a named offset is not valid according to RFC 2822 - they should use a numeric offset
  # To allow the parsing to continue, we assume UTC in this situation
  defp parse_time_zone(<<_tz_abbr::binary-size(3)>>) do
    "+0000"
  end

  defp parse_time_zone(time_zone) do
    time_zone
    |> String.trim_leading("(")
    |> String.trim_trailing(")")
  end

  @doc """
  Retrieves the "name" and "address" parts from an email message recipient
  (To, CC, etc.). The following is an example of recipient value:

      Full Name <fullname@company.tld>, another@company.tld

  In this example, `Full Name` is the "name" part and `fullname@company.tld` is
  the "address" part. `another@company.tld` does not have a "name" part, only
  an "address" part.

  The return value is a mixed list of tuples and strings, which should be
  interpreted in the following way:
  - When the element is just a string, it represents the "address" part only
  - When the element is a tuple, the format is `{name, address}`. Both "name"
    and "address" are strings
  """
  @spec parse_recipient_value(value :: String.t()) ::
          [{String.t(), String.t()} | String.t()]
  def parse_recipient_value(value) do
    Regex.scan(
      ~r/
    \s*
    (?:
      # Quoted name
      ((?<!\\)")
      (?<name>.*?)
      \1
      \s*
      <
      (?<email>[^<\s,]+@[^\s>,]+)
      >
    |
      # Non-quoted name
      (?<name2>[^\\",@]+?)
      \s*?
      <
      (?<email2>[^<\s,]+@[^\s>,]+)
      >
    |
      # Only email
      <?(?<email3>[^<\s,]+@[^\s>,]+)>?
    )
    ,?
    /x,
      value,
      capture: :all_names
    )
    |> Enum.map(fn
      # Scan is matching on named captures sorted alphabetically:
      # [email, email2, email3, name, name2]
      ["", "", address, "", ""] ->
        {"", address}

      [address, "", "", name, ""] ->
        {name, address}

      ["", address, "", "", name] ->
        {name, address}
    end)
    |> Enum.map(fn
      {"", address} -> address
      {name, address} -> {String.replace(name, "\\", ""), address}
    end)
  end

  defp parse_headers(message, headers, opts) do
    headers =
      Enum.reduce(headers, message.headers, fn header, headers ->
        {key, value} = parse_header(header, opts)
        put_header(headers, key, value)
      end)

    Map.put(message, :headers, headers)
  end

  def parse_header(header, opts) do
    [name, body] = String.split(header, ":", parts: 2)
    key = String.downcase(name)
    value = parse_header_value(key, body)

    value =
      case value do
        [value | params] = list when is_binary(value) and is_list(params) ->
          if is_params(params) do
            [value | concatenate_continuation_params(params, opts)]
          else
            list
          end

        value ->
          value
      end

    decoded = decode_header_value(key, value, opts)
    {key, decoded}
  end

  defp is_params([]), do: true
  defp is_params([{_key, _value} | params]), do: is_params(params)
  defp is_params([_ | _]), do: false

  defp put_header(headers, "received" = key, value),
    do: Map.update(headers, key, [value], &[value | &1])

  defp put_header(headers, key, value),
    do: Map.put(headers, key, value)

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

  defp parse_header_value("to", value),
    do: parse_recipient_value(value)

  defp parse_header_value("cc", value),
    do: parse_recipient_value(value)

  defp parse_header_value("from", value),
    do:
      parse_recipient_value(value)
      |> List.first()

  defp parse_header_value("reply-to", value),
    do:
      parse_recipient_value(value)
      |> List.first()

  defp parse_header_value("date", timestamp),
    do: to_datetime(timestamp)

  defp parse_header_value("received", value),
    do: parse_received_value(value)

  defp parse_header_value("content-type", value) do
    case List.wrap(parse_structured_header_value(value)) do
      [<<value::binary>>] -> [value, {"charset", "us-ascii"}]
      [_ | _] = header -> header
    end
  end

  defp parse_header_value("content-disposition", value),
    do: parse_structured_header_value(value)

  defp parse_header_value(_key, value),
    do: value

  defp decode_header_value(_key, nil, _opts),
    do: nil

  defp decode_header_value(_key, %DateTime{} = datetime, _opts),
    do: datetime

  defp decode_header_value(key, addresses, opts)
       when key in ["to", "cc", "from", "reply-to"] and is_list(addresses) do
    addresses =
      Enum.map(addresses, fn
        {name, email} ->
          decoded = parse_encoded_word(name, opts)
          {decoded, email}

        email ->
          email
      end)

    addresses
  end

  defp decode_header_value("from", {_name, _address} = value, opts) do
    [from] = decode_header_value("from", [value], opts)
    from
  end

  defp decode_header_value("from", value, _opts), do: value

  defp decode_header_value("received", value, _opts),
    do: value

  defp decode_header_value(_key, [value | [param | _params] = params], opts)
       when is_binary(value) and is_tuple(param) do
    decoded = parse_encoded_word(value, opts)
    params = Enum.map(params, fn {param, value} -> {param, parse_encoded_word(value, opts)} end)
    [decoded | params]
  end

  defp decode_header_value(_key, {name, email}, opts) do
    decoded = parse_encoded_word(name, opts)
    {decoded, email}
  end

  defp decode_header_value(_key, value, opts) do
    parse_encoded_word(value, opts)
  end

  # See https://tools.ietf.org/html/rfc2047
  defp parse_encoded_word("", _opts), do: ""

  defp parse_encoded_word(<<"=?", value::binary>>, opts) do
    case String.split(value, "?", parts: 4) do
      [charset, encoding, encoded_string, <<"=", remainder::binary>>] ->
        decoded_string =
          case String.upcase(encoding) do
            "Q" ->
              Mail.Encoders.QuotedPrintable.decode(String.replace(encoded_string, "_", " "))

            "B" ->
              Mail.Encoders.Base64.decode(encoded_string)
          end

        charset_handler = Keyword.get(opts, :charset_handler, fn _, string -> string end)
        [charset | _language] = String.split(charset, "*", parts: 2)
        decoded_string = charset_handler.(charset, decoded_string)

        # Remove space if immediately followed by another encoded word string
        remainder = Regex.replace(~r/\s+\=\?/, remainder, "=?")

        decoded_string <> parse_encoded_word(remainder, opts)

      _ ->
        # Not an encoded word, moving on
        "=?" <> parse_encoded_word(value, opts)
    end
  end

  defp parse_encoded_word(<<char::utf8, rest::binary>>, opts),
    do: <<char::utf8, parse_encoded_word(rest, opts)::binary>>

  defp parse_structured_header_value(
         string,
         value \\ nil,
         sub_types \\ [],
         part \\ :value,
         acc \\ ""
       )

  defp parse_structured_header_value("", value, [{key, nil} | sub_types], _part, acc) do
    [value | Enum.reverse([{key, acc} | sub_types])]
  end

  defp parse_structured_header_value("", value, sub_types, :param_name, _acc) do
    [value | Enum.reverse(sub_types)]
  end

  defp parse_structured_header_value("", nil, [], _part, acc) do
    acc
  end

  defp parse_structured_header_value("", value, [_ | _] = sub_types, _part, "") do
    [value | Enum.reverse(sub_types)]
  end

  defp parse_structured_header_value("", value, [], _part, acc) do
    [value, String.trim(acc)]
  end

  defp parse_structured_header_value("", value, sub_types, part, acc) do
    parse_structured_header_value("", value, sub_types, part, String.trim(acc))
  end

  defp parse_structured_header_value(<<"\"", rest::binary>>, value, sub_types, part, acc) do
    {string, rest} = parse_quoted_string(rest)
    parse_structured_header_value(rest, value, sub_types, part, <<acc::binary, string::binary>>)
  end

  defp parse_structured_header_value(<<";", rest::binary>>, nil, sub_types, part, acc)
       when part in [:value, :param_value] do
    parse_structured_header_value(rest, acc, sub_types, :param_name, "")
  end

  defp parse_structured_header_value(
         <<";", rest::binary>>,
         value,
         [{key, nil} | sub_types],
         :param_value,
         acc
       ) do
    parse_structured_header_value(rest, value, [{key, acc} | sub_types], :param_name, "")
  end

  defp parse_structured_header_value(<<"=", rest::binary>>, value, sub_types, :param_name, acc) do
    parse_structured_header_value(
      rest,
      value,
      [{key_to_atom(acc), nil} | sub_types],
      :param_value,
      ""
    )
  end

  defp parse_structured_header_value(<<char::utf8, rest::binary>>, value, sub_types, part, acc) do
    parse_structured_header_value(rest, value, sub_types, part, <<acc::binary, char::utf8>>)
  end

  defp parse_quoted_string(string, acc \\ "")

  defp parse_quoted_string(<<"\\", char, rest::binary>>, acc),
    do: parse_quoted_string(rest, <<acc::binary, char>>)

  defp parse_quoted_string(<<"\"", rest::binary>>, acc), do: {acc, rest}

  defp parse_quoted_string(<<char, rest::binary>>, acc),
    do: parse_quoted_string(rest, <<acc::binary, char>>)

  defp parse_received_value(value) do
    case String.split(value, ";") do
      [value, ""] ->
        [value]

      [value, date] ->
        {value, date} =
          case extract_comment(remove_timezone_comment(date)) do
            {date, nil} -> {value, date}
            {date, comment} -> {"#{value} #{comment}", date}
          end

        [value, {"date", to_datetime(remove_excess_whitespace(date))}]

      value ->
        value
    end
  end

  defp remove_timezone_comment(date_string) do
    string_size = date_string |> String.trim_trailing() |> byte_size()

    if string_size > 6 do
      case binary_part(date_string, string_size - 6, 6) do
        <<" (", _::binary-size(3), ")">> -> binary_part(date_string, 0, string_size - 6)
        _ -> date_string
      end
    else
      date_string
    end
  end

  defp extract_comment(string, state \\ :value, value \\ "", comment \\ nil)
  defp extract_comment("", _, value, comment), do: {value, comment}

  defp extract_comment(<<"(", rest::binary>>, :value, value, nil),
    do: extract_comment(rest, :comment, value, "(")

  defp extract_comment(<<")", rest::binary>>, :comment, value, comment),
    do: extract_comment(rest, :value, value, comment <> ")")

  defp extract_comment(<<char::utf8, rest::binary>>, :value, value, comment),
    do: extract_comment(rest, :value, <<value::binary, char::utf8>>, comment)

  defp extract_comment(<<char::utf8, rest::binary>>, :comment, value, comment),
    do: extract_comment(rest, :comment, value, <<comment::binary, char::utf8>>)

  defp remove_excess_whitespace(<<>>), do: <<>>

  defp remove_excess_whitespace(<<"  ", rest::binary>>),
    do: remove_excess_whitespace(<<" ", rest::binary>>)

  defp remove_excess_whitespace(<<"\t", rest::binary>>),
    do: remove_excess_whitespace(<<" ", rest::binary>>)

  defp remove_excess_whitespace(<<char::utf8, rest::binary>>),
    do: <<char::utf8, remove_excess_whitespace(rest)::binary>>

  defp parse_body_binary(%Mail.Message{multipart: true} = message, body_content, opts) do
    content_type = message.headers["content-type"]
    boundary = Mail.Proplist.get(content_type, "boundary")
    part_ranges = extract_parts_ranges(body_content, boundary)

    size_threshold = Keyword.get(opts, :max_part_size, 10_000_000)
    skip_large_parts? = Keyword.get(opts, :skip_large_parts?, false)

    parsed_parts =
      part_ranges
      |> Enum.map(fn {start, size} ->
        if skip_large_parts? and size > size_threshold do
          # Don't extract or parse large parts: return placeholder
          %Mail.Message{body: "[Part skipped: #{size} bytes - too large to parse]"}
        else
          String.trim_trailing(binary_part(body_content, start, size), "\r\n")
          |> parse(opts)
        end
      end)

    case parsed_parts do
      [] -> parse_body_binary(Map.put(message, :multipart, false), body_content, opts)
      _ -> Map.put(message, :parts, parsed_parts)
    end
  end

  # Empty body for non-multipart - set to empty string
  defp parse_body_binary(%Mail.Message{multipart: false} = message, "", _opts) do
    Map.put(message, :body, "")
  end

  # Empty body for multipart (shouldn't happen normally, but leave as nil)
  defp parse_body_binary(%Mail.Message{} = message, "", _opts) do
    message
  end

  # Simple (non-multipart) body
  defp parse_body_binary(%Mail.Message{} = message, body_content, opts) do
    # Normalize line endings without splitting into array
    normalized_body = String.replace(body_content, ~r/\r?\n/, "\r\n")
    decoded = decode(normalized_body, message, opts)
    Map.put(message, :body, decoded)
  end

  defp extract_parts_ranges(content, boundary) do
    start_boundary = "--" <> boundary
    end_boundary = "--" <> boundary <> "--"

    # Stream through content tracking byte offsets for boundaries
    content
    |> Stream.unfold(fn remaining ->
      case remaining |> :binary.split("\n") do
        [""] -> nil
        [line, rest] -> {{line, byte_size(line) + 1}, rest}
        [line] -> {{line, byte_size(line)}, ""}
      end
    end)
    |> Stream.map(fn {line, size} -> {String.trim_trailing(line), size} end)
    |> Enum.reduce_while({[], 0, nil, nil}, fn {line, line_size}, {_, offset, _, _} = acc ->
      new_offset = offset + line_size
      accumulate_part_range({line, new_offset}, acc, start_boundary, end_boundary)
    end)
    |> extract_final_part_range(content)
    |> Enum.reverse()
  end

  # End boundary found: but no part was started
  defp accumulate_part_range(
         {line, new_offset},
         {ranges, _offset, _state, nil},
         _start_boundary,
         end_boundary
       )
       when line == end_boundary do
    {:halt, {ranges, new_offset, :done, nil}}
  end

  # End boundary found: append new [part_start -> offset] range
  defp accumulate_part_range(
         {line, new_offset},
         {ranges, offset, _state, part_start},
         _start_boundary,
         end_boundary
       )
       when line == end_boundary do
    ranges = [{part_start, offset - part_start} | ranges]
    {:halt, {ranges, new_offset, :done, nil}}
  end

  # Start boundary found: first boundary
  defp accumulate_part_range(
         {line, new_offset},
         {ranges, _offset, nil, _part_start},
         start_boundary,
         _end_boundary
       )
       when line == start_boundary do
    {:cont, {ranges, new_offset, :collecting, new_offset}}
  end

  # Start boundary found: subsequent boundary
  defp accumulate_part_range(
         {line, new_offset},
         {ranges, offset, _state, part_start},
         start_boundary,
         _end_boundary
       )
       when line == start_boundary do
    part_range = {part_start, offset - part_start}
    {:cont, {[part_range | ranges], new_offset, :collecting, new_offset}}
  end

  # Inside a part: just track offset
  defp accumulate_part_range(
         {_line, new_offset},
         {ranges, _offset, :collecting, part_start},
         _start_boundary,
         _end_boundary
       ) do
    {:cont, {ranges, new_offset, :collecting, part_start}}
  end

  # Before first boundary: ignore
  defp accumulate_part_range(
         {_line, new_offset},
         {ranges, _offset, state, part_start},
         _start_boundary,
         _end_boundary
       ) do
    {:cont, {ranges, new_offset, state, part_start}}
  end

  # Handle case where end boundary wasn't found (still :collecting)
  defp extract_final_part_range({ranges, _offset, :collecting, start}, content) do
    # Add final part from start to end of content (if it has content (not empty or just whitespace)
    part_size = byte_size(content) - start

    if part_size > 0 and contains_non_whitespace?(content, start, start + part_size) do
      [{start, part_size} | ranges]
    else
      ranges
    end
  end

  defp extract_final_part_range({ranges, _offset, _state, _start}, _content) do
    ranges
  end

  @whitespaces [?\s, ?\t, ?\r, ?\n]
  defp contains_non_whitespace?(content, pos, limit) when pos < limit do
    case :binary.at(content, pos) do
      char when char in @whitespaces -> contains_non_whitespace?(content, pos + 1, limit)
      _ -> true
    end
  end

  defp contains_non_whitespace?(_, _, _), do: false

  defp key_to_atom(key) do
    key
    |> String.trim()
    |> String.downcase()
    |> String.replace("-", "_")
  end

  # This is for RFC 2231 parameters that are split into multiple parts
  defp concatenate_continuation_params(params, opts) do
    params
    |> Enum.map(fn
      # Find parameters that are split into multiple parts
      {key, value} when is_binary(value) ->
        case String.split(key, "*", parts: 2) do
          [key, part] ->
            {{key, part}, value}

          _ ->
            {key, value}
        end

      kv ->
        kv
    end)
    # Group the split parameters by key
    |> Enum.reduce({nil, []}, fn
      {{key, <<"0", _::binary>> = part}, value}, {_prev_key, acc} ->
        # The continuations are tagged so they don’t conflict with pre-parsed parameters, like DKIM
        {key, [{:continuation, key, [{part, value}]} | acc]}

      {{key, part}, value}, {key, [{:continuation, key, values} | acc]} ->
        {key, [{:continuation, key, [{part, value} | values]} | acc]}

      {key, value}, {_, acc} ->
        {nil, [{key, value} | acc]}
    end)
    # We don’t need the previous key tracking value anymore
    |> elem(1)
    # Parse and join the continuations
    |> Enum.map(fn
      {:continuation, key, values} ->
        # The values are in reverse order from the above grouping reduction, so we need to reverse them
        {charset, _language, value} = parse_continuation_part(Enum.reverse(values))

        converted_value =
          if charset do
            charset_handler = Keyword.get(opts, :charset_handler, fn _, string -> string end)
            charset_handler.(charset, value)
          else
            value
          end

        {key, converted_value}

      {key, value} ->
        {key, value}
    end)
    # Reverse the list to maintain the original order
    |> Enum.reverse()
  end

  defp parse_continuation_part(continuations) do
    {charset, language, value} =
      continuations
      |> Enum.reduce({nil, nil, <<>>}, fn {continuation, value_part},
                                          {charset, language, value} ->
        cond do
          continuation == "0*" ->
            case String.split(value_part, "'", parts: 3) do
              ["", language, value] ->
                {nil, language, URI.decode(value)}

              [charset, language, value] ->
                {charset, language, URI.decode(value)}
            end

          is_binary(continuation) and String.ends_with?(continuation, "*") ->
            {charset, language, value <> URI.decode(value_part)}

          true ->
            {charset, language, value <> value_part}
        end
      end)

    {charset, language, value}
  end

  defp multipart?(headers) do
    content_type = headers["content-type"]

    !!case content_type do
      nil -> nil
      type when is_binary(type) -> nil
      content_type -> Mail.Proplist.get(content_type, "boundary")
    end
  end

  defp decode(body, message, opts) do
    body = String.trim_trailing(body)
    content_type = message.headers["content-type"]
    charset = Mail.Proplist.get(content_type, "charset")
    transfer_encoding = Mail.Message.get_header(message, "content-transfer-encoding")
    decoded = Mail.Encoder.decode(body, transfer_encoding)

    if charset do
      charset_handler = Keyword.get(opts, :charset_handler, fn _, string -> string end)
      charset_handler.(charset, decoded)
    else
      decoded
    end
  end
end
