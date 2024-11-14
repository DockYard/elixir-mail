defmodule Mail.Renderers.RFC2822 do
  import Mail.Message, only: [match_content_type?: 2]

  @days ~w(Mon Tue Wed Thu Fri Sat Sun)
  @months ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)

  @moduledoc """
  RFC2822 Parser

  Will attempt to render a valid RFC2822 message
  from a `%Mail.Message{}` data model.

      Mail.Renderers.RFC2822.render(message)

  The email validation regex defaults to `~r/\w+@\w+\.\w+/`
  and can be overridden with the following config:

      config :mail, email_regex: custom_regex
  """

  @blacklisted_headers ["bcc"]
  @address_types ["From", "To", "Reply-To", "Cc", "Bcc"]

  # https://tools.ietf.org/html/rfc2822#section-3.4.1
  @email_validation_regex Application.compile_env(
                            :mail,
                            :email_regex,
                            ~r/[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,64}/
                          )

  @doc """
  Renders a message according to the RFC2822 spec
  """
  def render(%Mail.Message{multipart: true} = message) do
    message
    |> reorganize
    |> Mail.Message.put_header(:mime_version, "1.0")
    |> render_part()
  end

  def render(%Mail.Message{} = message),
    do: render_part(message)

  @doc """
  Render an individual part

  An optional function can be passed used during the rendering of each
  individual part
  """
  def render_part(message, render_part_function \\ &render_part/1)

  def render_part(%Mail.Message{multipart: true} = message, fun) do
    boundary = Mail.Message.get_boundary(message)
    message = Mail.Message.put_boundary(message, boundary)

    headers = render_headers(message.headers, @blacklisted_headers)
    boundary = "--#{boundary}"

    parts =
      render_parts(message.parts, fun)
      |> Enum.join("\r\n\r\n#{boundary}\r\n")

    "#{headers}\r\n\r\n#{boundary}\r\n#{parts}\r\n#{boundary}--"
  end

  def render_part(%Mail.Message{} = message, _fun) do
    encoded_body = encode(message.body, message)
    "#{render_headers(message.headers, @blacklisted_headers)}\r\n\r\n#{encoded_body}"
  end

  def render_parts(parts, fun \\ &render_part/1) when is_list(parts),
    do: Enum.map(parts, &fun.(&1))

  defp render_header({key, value}), do: render_header(key, value)

  @doc """
  Will render a given header according to the RFC2822 spec
  """
  def render_header(key, value)

  def render_header(_key, nil), do: nil
  def render_header(_key, []), do: nil
  def render_header(_key, ""), do: nil
  def render_header(key, <<" ", rest::binary>>), do: render_header(key, rest)

  def render_header(key, value) when is_atom(key),
    do: render_header(Atom.to_string(key), value)

  def render_header(key, value) do
    key =
      key
      |> String.replace("_", "-")
      |> String.split("-")
      |> Enum.map(&String.capitalize(&1))
      |> Enum.join("-")

    key <> ": " <> render_header_value(key, value)
  end

  defp render_header_value("Date", date_time),
    do: timestamp_from_datetime(date_time)

  defp render_header_value(address_type, addresses)
       when is_list(addresses) and address_type in @address_types,
       do:
         Enum.map(addresses, &render_address(&1))
         |> Enum.join(", ")

  defp render_header_value(address_type, address) when address_type in @address_types,
    do: render_address(address)

  defp render_header_value("Content-Transfer-Encoding" = key, value) when is_atom(value) do
    value =
      value
      |> Atom.to_string()
      |> String.replace("_", "-")

    render_header_value(key, value)
  end

  defp render_header_value(_key, [value | subtypes]),
    do:
      Enum.join([encode_header_value(value, :quoted_printable) | render_subtypes(subtypes)], "; ")

  defp render_header_value(key, value),
    do: render_header_value(key, List.wrap(value))

  defp validate_address(address) do
    case Regex.match?(@email_validation_regex, address) do
      true ->
        address

      false ->
        raise ArgumentError,
          message: """
          The email address `#{address}` is invalid.
          """
    end
  end

  defp render_address({name, email}), do: ~s("#{name}" <#{validate_address(email)}>)
  defp render_address(email), do: validate_address(email)
  defp render_subtypes([]), do: []

  defp render_subtypes([{key, value} | subtypes]) when is_atom(key),
    do: render_subtypes([{Atom.to_string(key), value} | subtypes])

  defp render_subtypes([{"boundary", value} | subtypes]) do
    [~s(boundary="#{value}") | render_subtypes(subtypes)]
  end

  defp render_subtypes([{key, value} | subtypes]) do
    key = String.replace(key, "_", "-")
    value = encode_header_value(value, :quoted_printable)
    ["#{key}=#{value}" | render_subtypes(subtypes)]
  end

  @doc """
  Will render all headers according to the RFC2822 spec

  Can take an optional list of headers to blacklist
  """
  def render_headers(headers, blacklist \\ [])

  def render_headers(map, blacklist) when is_map(map) do
    map
    |> Map.to_list()
    |> render_headers(blacklist)
  end

  def render_headers(list, blacklist) when is_list(list) do
    list
    |> Enum.reject(&Enum.member?(blacklist, elem(&1, 0)))
    |> Enum.map(&render_header/1)
    |> Enum.filter(& &1)
    |> Enum.reverse()
    |> Enum.join("\r\n")
  end

  # As stated at https://datatracker.ietf.org/doc/html/rfc2047#section-2, encoded words must be
  # split in 76 chars including its surroundings and delimmiters.
  # Since enclosing starts with =?UTF-8?Q? and ends with ?=, max length should be 64
  defp encode_header_value(header_value, :quoted_printable) do
    case Mail.Encoders.QuotedPrintable.encode(header_value, 64) do
      ^header_value -> header_value
      encoded -> wrap_encoded_words(encoded)
    end
  end

  defp wrap_encoded_words(value) do
    :binary.split(value, "=\r\n", [:global])
    |> Enum.map(fn chunk -> <<"=?UTF-8?Q?", chunk::binary, "?=">> end)
    |> Enum.join()
  end

  @doc """
  Builds a RFC2822 timestamp from an Erlang timestamp

  [RFC2822 3.3 - Date and Time Specification](https://tools.ietf.org/html/rfc2822#section-3.3)

  This function always assumes the Erlang timestamp is in Universal time, not Local time
  """
  def timestamp_from_datetime({{year, month, day} = date, {hour, minute, second}}) do
    day_name = day_name(:calendar.day_of_the_week(date))
    month_name = Enum.at(@months, month - 1)

    date_part = "#{day_name}, #{day} #{month_name} #{year}"
    time_part = "#{pad(hour)}:#{pad(minute)}:#{pad(second)}"

    date_part <> " " <> time_part <> " +0000"
  end

  def timestamp_from_datetime(%DateTime{} = datetime) do
    %{
      year: year,
      month: month,
      day: day,
      hour: hour,
      minute: minute,
      second: second,
      utc_offset: utc_offset,
      std_offset: std_offset
    } = datetime

    day_name = Enum.at(@days, :calendar.day_of_the_week({year, month, day}) - 1)
    month_name = Enum.at(@months, month - 1)

    date_part = "#{day_name}, #{day} #{month_name} #{year}"
    time_part = "#{pad(hour)}:#{pad(minute)}:#{pad(second)}"

    date_part <> " " <> time_part <> " " <> render_time_zone(utc_offset, std_offset)
  end

  defp render_time_zone(utc_offset, std_offset) do
    offset = abs(utc_offset + std_offset)
    minutes = div(rem(offset, 3600), 60)
    hours = div(offset, 3600)

    if(utc_offset >= 0, do: "+", else: "-") <> "#{pad(hours)}#{pad(minutes)}"
  end

  @days
  |> Enum.with_index(1)
  |> Enum.each(fn {day, index} ->
    defp day_name(unquote(index)), do: unquote(day)
  end)

  defp pad(num) do
    num
    |> Integer.to_string()
    |> String.pad_leading(2, "0")
  end

  defp split_attachment_parts(message) do
    Enum.reduce(message.parts, [[], [], []], fn part, [texts, mixed, inlines] ->
      cond do
        match_content_type?(part, ~r/text\/(plain|html)/) ->
          [[part | texts], mixed, inlines]
        Mail.Message.is_inline_attachment?(part) ->
          [texts, mixed, [part | inlines]]
        true -> # a mixed part - most likely an attachment
          [texts, [part | mixed], inlines]
      end
    end)
    |> Enum.map(&Enum.reverse/1) # retain ordering
  end

  defp reorganize(%Mail.Message{multipart: true} = message) do
    content_type = Mail.Message.get_content_type(message)

    [text_parts, mixed, inlines] = split_attachment_parts(message)
    has_inline = Enum.any?(inlines)
    has_mixed_parts = Enum.any?(mixed)
    has_text_parts = Enum.any?(text_parts)

    if has_inline || has_mixed_parts do
      # If any attaching, change content type to mixed
      content_type = List.replace_at(content_type, 0, "multipart/mixed")
      message = Mail.Message.put_content_type(message, content_type)

      if has_text_parts do
        # If any text with attachments, wrap in new part
        body_part =
          Mail.build_multipart()
          |> Mail.Message.put_content_type("multipart/alternative")
          |> Mail.Message.put_parts(text_parts)

        # If any inline attachments, wrap together with text
        # in a "multipart/related" part
        body_part = if has_inline do
          Mail.build_multipart()
          |> Mail.Message.put_content_type("multipart/related")
          |> Mail.Message.put_part(body_part)
          |> Mail.Message.put_parts(inlines)
        else
          body_part
        end

        message
        |> Mail.Message.delete_all_parts()
        |> Mail.Message.put_part(body_part)
        |> Mail.Message.put_parts(mixed)
      else
        # If not text sections, leave all parts as is
        message
      end
    else
      # If only text, change content type to alternative
      content_type = List.replace_at(content_type, 0, "multipart/alternative")
      Mail.Message.put_content_type(message, content_type)
    end
  end

  defp encode(body, message) do
    Mail.Encoder.encode(body, Mail.Message.get_header(message, "content-transfer-encoding"))
  end
end
