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

  defp render_header_value(header, value)
       when header in [
              # RFC 5322
              "Message-Id",
              "In-Reply-To",
              "References",
              "Resent-Message-Id",
              # RFC 2045
              "Content-Id"
            ] do
    value
    |> List.wrap()
    |> Enum.map(&to_string/1)
    |> Enum.join(" ")
  end

  defp render_header_value(key, [value | subtypes]) do
    encoded_header_value =
      value
      |> encode_header_value(key)
      |> fold_header_value(key)

    Enum.join([encoded_header_value | render_subtypes(subtypes)], "; ")
  end

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

  defp render_address({name, email}),
    do: "#{encode_header_value(~s("#{name}"))} <#{validate_address(email)}>"

  defp render_address(email), do: validate_address(email)

  defp render_subtypes([]), do: []

  defp render_subtypes([{key, value} | subtypes]) when is_atom(key),
    do: render_subtypes([{Atom.to_string(key), value} | subtypes])

  defp render_subtypes([{"boundary", value} | subtypes]) do
    [~s(boundary="#{value}") | render_subtypes(subtypes)]
  end

  defp render_subtypes([{key, value} | subtypes]) do
    key = String.replace(key, "_", "-")
    value = encode_header_value(value)

    value =
      if value =~ ~r/[\s()<>@,;:\\<\/\[\]?=]/ do
        "\"#{value}\""
      else
        value
      end

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

  defp encode_header_value(header_value, header \\ "") do
    if ascii_string?(header_value) do
      header_value
    else
      # From RFC2047 §2 https://datatracker.ietf.org/doc/html/rfc2047#section-2
      # An 'encoded-word' may not be more than 75 characters long, including
      # 'charset', 'encoding', 'encoded-text', and delimiters.  If it is
      # desirable to encode more text than will fit in an 'encoded-word' of
      # 75 characters, multiple 'encoded-word's (separated by CRLF SPACE) may
      # be used.

      # From RFC2047 §5 https://datatracker.ietf.org/doc/html/rfc2047#section-5
      # ... an 'encoded-word' that appears in a
      # header field defined as '*text' MUST be separated from any adjacent
      # 'encoded-word' or 'text' by 'linear-white-space'.

      header_value
      |> Mail.Encoders.QuotedPrintable.encode(
        # 75 is maximum length, subtract wrapping, add trailing "=" we strip out
        75 - byte_size("=?UTF-8?Q?") - byte_size("?=") + byte_size("="),
        <<>>,
        byte_size(header) + byte_size(": ")
      )
      |> :binary.split("=\r\n", [:global])
      |> Enum.map(fn chunk ->
        # SPACE must be encoded as "_" and then everything wrapped
        # to indicate an 'encoded-word'
        chunk = String.replace(chunk, " ", "_")
        <<"=?UTF-8?Q?", chunk::binary, "?=">>
      end)
      |> Enum.join(" ")
    end
  end

  # Returns `true` if string only contains 7-bit characters or is empty
  defp ascii_string?(value) when is_binary(value), do: is_nil(Regex.run(~r/[^\x00-\x7F]+/, value))

  defp fold_header_value(header_value, header) do
    # This _should_ handle most cases of header folding, but the RFC mentions for
    # structured headers that contain email addresses, that folding should occur
    # after commas (so avoiding folding in the middle of the name/email-address pair,
    # even if there's foldable spaces there).  As such, this is currently not
    # used on fields that are known to have that structure.

    # desired header line limit is 78 characters
    limit = 78

    # Split on SPACE or HTAB but only if followed by non-whitespace, so each
    # subsequent part starts with a whitespace we can potentially fold on.
    # Trailing whitespace removed to prevent case where final line is only whitespace.
    [first_part | remaining_parts] =
      header_value
      |> String.trim_trailing()
      |> then(&Regex.split(~r/[ \t]+[^ \t]+/, &1, include_captures: true, trim: true))

    {lines, current, _prefix_length} =
      Enum.reduce(
        remaining_parts,
        {[], first_part, byte_size(header) + byte_size(": ")},
        fn part, {lines, current, prefix_length} ->
          if prefix_length + byte_size(current) + byte_size(part) <= limit do
            {lines, current <> part, prefix_length}
          else
            # Adding chunks together are too long, so put `current` part into `lines`
            # and `part` in the accumulator for the next iteration.
            # Note: also includes case where `current` is too long on its own (because
            # it can't be divided)
            {[current | lines], part, 0}
          end
        end
      )

    # add final line and then join with CRLF
    [current | lines]
    |> Enum.reverse()
    |> Enum.join("\r\n")
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

  defp reorganize(%Mail.Message{multipart: true, headers: headers} = message) do
    {text_parts, attachments} =
      message.parts
      |> Enum.split_with(&match_content_type?(&1, ~r/text\/(plain|html)/))

    {inline_attachments, other_attachments} =
      Enum.split_with(attachments, &Mail.Message.is_attachment?(&1, :inline))

    message =
      if Enum.empty?(text_parts) do
        Mail.Message.put_content_type(message, "multipart/mixed")
      else
        alternative =
          case text_parts do
            [part] ->
              part

            text_parts ->
              Mail.build_multipart()
              |> Mail.Message.put_content_type("multipart/alternative")
              |> Mail.Message.put_parts(text_parts)
          end

        related =
          if Enum.empty?(inline_attachments) do
            alternative
          else
            Mail.build_multipart()
            |> Mail.Message.put_content_type("multipart/related")
            |> Mail.Message.put_part(alternative)
            |> Mail.Message.put_parts(inline_attachments)
          end

        if Enum.empty?(other_attachments) do
          related
        else
          Mail.build_multipart()
          |> Mail.Message.put_content_type("multipart/mixed")
          |> Mail.Message.put_part(related)
          |> Mail.Message.put_parts(other_attachments)
        end
      end

    Mail.Message.put_headers(message, headers)
  end

  defp encode(body, message) do
    Mail.Encoder.encode(body, Mail.Message.get_header(message, "content-transfer-encoding"))
  end
end
