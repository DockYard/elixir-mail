defmodule Mail do
  @moduledoc """
  Mail primitive for composing messages.

  Build a mail message with the `Mail` struct

      mail =
        Mail.build_multipart()
        |> put_subject("How is it going?")
        |> Mail.put_text("Just checking in")
        |> Mail.put_to("joe@example.com")
        |> Mail.put_from("brian@example.com")

  """

  @doc """
  Build a single-part mail
  """
  def build(),
    do: %Mail.Message{}

  @doc """
  Build a multi-part mail
  """
  def build_multipart,
    do: %Mail.Message{multipart: true}

  @doc """
  Primary hook for parsing

  You can pass in your own custom parse module. That module
  must have a `parse/1` function that accepts a string or list of lines

  By default the `parser` will be `Mail.Parsers.RFC2822`
  """
  def parse(message, parser \\ Mail.Parsers.RFC2822) do
    parser.parse(message)
  end

  @doc """
  Add a plaintext part to the message

  Shortcut function for adding plain text part

      Mail.put_text(%Mail.Message{}, "Some plain text")

  If a text part already exists this function will replace that existing
  part with the new part.

  ## Options

  * `:charset` - The character encoding standard for content type
  """
  def put_text(message, body, opts \\ [])

  def put_text(%Mail.Message{multipart: true} = message, body, opts) do
    message =
      case Enum.find(message.parts, &Mail.Message.match_body_text/1) do
        %Mail.Message{} = part -> Mail.Message.delete_part(message, part)
        _ -> message
      end

    Mail.Message.put_part(message, Mail.Message.build_text(body, opts))
  end

  def put_text(%Mail.Message{} = message, body, opts) do
    content_type =
      case opts do
        charset: charset ->
          ["text/plain", {"charset", charset}]

        _else ->
          ["text/plain", {"charset", default_charset()}]
      end

    Mail.Message.put_body(message, body)
    |> Mail.Message.put_header(:content_transfer_encoding, :quoted_printable)
    |> Mail.Message.put_content_type(content_type)
  end

  @doc """
  Find the last text part of a given mail

  RFC 2046, §5.1.4 “In general, the best choice is the LAST part of a type supported by the recipient system's local environment.”

  If single part with `content-type` "text/plain", returns itself
  If single part without `content-type` "text/plain", returns `nil`
  If multipart with part having `content-type` "text/plain" will return that part
  If multipart without part having `content-type` "text/plain" will return `nil`
  """
  def get_text(%Mail.Message{multipart: true} = message) do
    Enum.reduce_while(Enum.reverse(message.parts), nil, fn sub_message, acc ->
      text_part = get_text(sub_message)
      if text_part, do: {:halt, text_part}, else: {:cont, acc}
    end)
  end

  def get_text(%Mail.Message{headers: %{"content-type" => ["text/plain" | _]}} = message),
    do: message

  def get_text(%Mail.Message{}), do: nil

  @doc """
  Add an HTML part to the message

      Mail.put_html(%Mail.Message{}, "<span>Some HTML</span>")

  If a text part already exists this function will replace that existing
  part with the new part.

  ## Options

  * `:charset` - The character encoding standard for content type
  """
  def put_html(message, body, opts \\ [])

  def put_html(%Mail.Message{multipart: true} = message, body, opts) do
    message =
      case Enum.find(message.parts, &Mail.Message.match_content_type?(&1, "text/html")) do
        %Mail.Message{} = part -> Mail.Message.delete_part(message, part)
        _ -> message
      end

    Mail.Message.put_part(message, Mail.Message.build_html(body, opts))
  end

  def put_html(%Mail.Message{} = message, body, opts) do
    content_type =
      case opts do
        charset: charset ->
          ["text/html", {"charset", charset}]

        _else ->
          ["text/html", {"charset", default_charset()}]
      end

    Mail.Message.put_body(message, body)
    |> Mail.Message.put_header(:content_transfer_encoding, :quoted_printable)
    |> Mail.Message.put_content_type(content_type)
  end

  @doc """
  Find the last html part of a given mail

  RFC 2046, §5.1.4 “In general, the best choice is the LAST part of a type supported by the recipient system's local environment.”

  If single part with `content-type` "text/html", returns itself
  If single part without `content-type` "text/html", returns `nil`
  If multipart with part having `content-type` "text/html" will return that part
  If multipart without part having `content-type` "text/html" will return `nil`
  """
  def get_html(%Mail.Message{multipart: true} = message) do
    Enum.reduce_while(Enum.reverse(message.parts), nil, fn sub_message, acc ->
      html_part = get_html(sub_message)
      if html_part, do: {:halt, html_part}, else: {:cont, acc}
    end)
  end

  def get_html(%Mail.Message{headers: %{"content-type" => "text/html"}} = message), do: message

  def get_html(%Mail.Message{headers: %{"content-type" => ["text/html", _]}} = message),
    do: message

  def get_html(%Mail.Message{}), do: nil

  defp default_charset do
    "UTF-8"
  end

  @doc """
  Add an attachment part to the message

      Mail.put_attachment(%Mail.Message{}, "README.md")
      Mail.put_attachment(%Mail.Message{}, {"README.md", data})

  Each call will add a new attachment part.
  """

  def put_attachment(message, path_or_file_tuple, opts \\ [])

  def put_attachment(%Mail.Message{multipart: true} = message, path, opts) when is_binary(path),
    do: Mail.Message.put_part(message, Mail.Message.build_attachment(path, opts))

  def put_attachment(%Mail.Message{multipart: true} = message, {filename, data}, opts),
    do: Mail.Message.put_part(message, Mail.Message.build_attachment({filename, data}, opts))

  def put_attachment(%Mail.Message{} = message, path, opts) when is_binary(path),
    do: Mail.Message.put_attachment(message, path, opts)

  def put_attachment(%Mail.Message{} = message, {filename, data}, opts),
    do: Mail.Message.put_attachment(message, {filename, data}, opts)

  @doc """
  Determines the message has any non-inline attachment parts

  Returns a `Boolean`
  """
  def has_attachments?(%Mail.Message{} = message) do
    has_message?(message, &Mail.Message.is_attachment?/1)
  end

  @doc """
  Determines the message has any inline attachment parts

  Returns a `Boolean`
  """
  def has_inline_attachments?(%Mail.Message{} = message) do
    has_message?(message, &Mail.Message.is_inline_attachment?/1)
  end

  @doc """
  Determines the message has any inline attachment parts

  Returns a `Boolean`
  """
  def has_any_attachments?(%Mail.Message{} = message) do
    has_message?(message, &Mail.Message.is_any_attachment?/1)
  end

  @doc """
  Determines the message has any text parts

  Returns a `Boolean`
  """
  def has_text_parts?(%Mail.Message{} = message) do
    has_message?(message, &Mail.Message.is_text_part?/1)
  end

  defp has_message?(%Mail.Message{} = message, condition) do
    walk_parts([message], {:cont, false}, fn message, _acc ->
      case condition.(message) do
        true -> {:halt, true}
        false -> {:cont, false}
      end
    end)
    |> elem(1)
  end

  @doc """
  Walks the message parts and collects all attachments

  Each member in the list is `{filename, content}`
  """
  def get_attachments(%Mail.Message{} = message) do
    walk_parts([message], {:cont, []}, fn message, acc ->
      case Mail.Message.is_attachment?(message) do
        true ->
          filename =
            case List.wrap(Mail.Message.get_header(message, :content_disposition)) do
              ["attachment" | properties] ->
                Enum.find_value(properties, "Unknown", fn {key, value} ->
                  key == "filename" && value
                end)
            end

          {:cont, List.insert_at(acc, -1, {filename, message.body})}

        false ->
          {:cont, acc}
      end
    end)
    |> elem(1)
  end

  defp walk_parts(_parts, {:halt, acc}, _fun), do: {:halt, acc}
  defp walk_parts([], {:cont, acc}, _fun), do: {:cont, acc}

  defp walk_parts([message | parts], {:cont, acc}, fun) do
    {tag, acc} = fun.(message, acc)
    {tag, acc} = walk_parts(message.parts, {tag, acc}, fun)
    walk_parts(parts, {tag, acc}, fun)
  end

  @doc """
  Add a new `subject` header

  ## Examples

      iex> Mail.put_subject(%Mail.Message{}, "Welcome to DockYard!")
      %Mail.Message{headers: %{"subject" => "Welcome to DockYard!"}}
  """
  def put_subject(message, subject),
    do: Mail.Message.put_header(message, "subject", subject)

  @doc ~S"""
  Retrieve the `subject` header
  """
  def get_subject(message),
    do: Mail.Message.get_header(message, "subject")

  @doc """
  Add new recipients to the `to` header

  Recipients can be added as a single string or a list of strings.
  The list of recipients will be concated to the previous value.

  ## Examples

      iex> Mail.put_to(%Mail.Message{}, "one@example.com")
      %Mail.Message{headers: %{"to" => ["one@example.com"]}}

      iex> Mail.put_to(%Mail.Message{}, ["one@example.com", "two@example.com"])
      %Mail.Message{headers: %{"to" => ["one@example.com", "two@example.com"]}}

      iex> Mail.put_to(%Mail.Message{}, "one@example.com")
      iex> |> Mail.put_to(["two@example.com", "three@example.com"])
      %Mail.Message{headers: %{"to" => ["one@example.com", "two@example.com", "three@example.com"]}}

  The value of a recipient must conform to either a string value or a tuple with two elements,
  otherwise an `ArgumentError` is raised.

  Valid forms:
  * `"user@example.com"`
  * `"Test User <user@example.com>"`
  * `{"Test User", "user@example.com"}`
  """
  def put_to(message, recipients)

  def put_to(message, recipients) when is_list(recipients) do
    validate_recipients(recipients)
    Mail.Message.put_header(message, "to", (get_to(message) || []) ++ recipients)
  end

  def put_to(message, recipient),
    do: put_to(message, [recipient])

  @doc ~S"""
  Retrieves the list of recipients from the `to` header
  """
  def get_to(message),
    do: Mail.Message.get_header(message, "to")

  @doc """
  Add new recipients to the `cc` header

  Recipients can be added as a single string or a list of strings.
  The list of recipients will be concated to the previous value.

  ## Examples

      iex> Mail.put_cc(%Mail.Message{}, "one@example.com")
      %Mail.Message{headers: %{"cc" => ["one@example.com"]}}

      iex> Mail.put_cc(%Mail.Message{}, ["one@example.com", "two@example.com"])
      %Mail.Message{headers: %{"cc" => ["one@example.com", "two@example.com"]}}

      iex> Mail.put_cc(%Mail.Message{}, "one@example.com")
      iex> |> Mail.put_cc(["two@example.com", "three@example.com"])
      %Mail.Message{headers: %{"cc" => ["one@example.com", "two@example.com", "three@example.com"]}}

  The value of a recipient must conform to either a string value or a tuple with two elements,
  otherwise an `ArgumentError` is raised.

  Valid forms:
  * `"user@example.com"`
  * `"Test User <user@example.com>"`
  * `{"Test User", "user@example.com"}`
  """
  def put_cc(message, recipients)

  def put_cc(message, recipients) when is_list(recipients) do
    validate_recipients(recipients)
    Mail.Message.put_header(message, "cc", (get_cc(message) || []) ++ recipients)
  end

  def put_cc(message, recipient),
    do: put_cc(message, [recipient])

  @doc ~S"""
  Retrieves the recipients from the `cc` header
  """
  def get_cc(message),
    do: Mail.Message.get_header(message, "cc")

  @doc """
  Add new recipients to the `bcc` header

  Recipients can be added as a single string or a list of strings.
  The list of recipients will be concated to the previous value.

  ## Examples

      iex> Mail.put_bcc(%Mail.Message{}, "one@example.com")
      %Mail.Message{headers: %{"bcc" => ["one@example.com"]}}

      iex> Mail.put_bcc(%Mail.Message{}, ["one@example.com", "two@example.com"])
      %Mail.Message{headers: %{"bcc" => ["one@example.com", "two@example.com"]}}

      iex> Mail.put_bcc(%Mail.Message{}, "one@example.com")
      iex> |> Mail.put_bcc(["two@example.com", "three@example.com"])
      %Mail.Message{headers: %{"bcc" => ["one@example.com", "two@example.com", "three@example.com"]}}

  The value of a recipient must conform to either a string value or a tuple with two elements,
  otherwise an `ArgumentError` is raised.

  Valid forms:
  * `"user@example.com"`
  * `"Test User <user@example.com>"`
  * `{"Test User", "user@example.com"}`
  """
  def put_bcc(message, recipients)

  def put_bcc(message, recipients) when is_list(recipients) do
    validate_recipients(recipients)
    Mail.Message.put_header(message, "bcc", (get_bcc(message) || []) ++ recipients)
  end

  def put_bcc(message, recipient),
    do: put_bcc(message, [recipient])

  @doc ~S"""
  Retrieves the recipients from the `bcc` header
  """
  def get_bcc(message),
    do: Mail.Message.get_header(message, "bcc")

  @doc """
  Add a new `from` header

  ## Examples

      iex> Mail.put_from(%Mail.Message{}, "user@example.com")
      %Mail.Message{headers: %{"from" => "user@example.com"}}
  """
  def put_from(message, sender),
    do: Mail.Message.put_header(message, "from", sender)

  @doc ~S"""
  Retrieves the `from` header
  """
  def get_from(message),
    do: Mail.Message.get_header(message, "from")

  @doc """
  Add a new `reply-to` header

  ## Examples

      iex> Mail.put_reply_to(%Mail.Message{}, "user@example.com")
      %Mail.Message{headers: %{"reply-to" => "user@example.com"}}
  """
  def put_reply_to(message, reply_address),
    do: Mail.Message.put_header(message, "reply-to", reply_address)

  @doc ~S"""
  Retrieves the `reply-to` header
  """
  def get_reply_to(message),
    do: Mail.Message.get_header(message, "reply-to")

  @doc """
  Returns a unique list of all recipients

  Will collect all recipients from `to`, `cc`, and `bcc`
  and returns a unique list of recipients.
  """
  def all_recipients(message) do
    (List.wrap(Mail.get_to(message)) ++
       List.wrap(Mail.get_cc(message)) ++ List.wrap(Mail.get_bcc(message)))
    |> Enum.uniq()
  end

  @doc """
  Primary hook for rendering

  You can pass in your own custom render module. That module
  must have `render/1` function that accepts a `Mail.Message` struct.

  By default the `renderer` will be `Mail.Renderers.RFC2822`
  """
  def render(message, renderer \\ Mail.Renderers.RFC2822) do
    renderer.render(message)
  end

  defp validate_recipients([]), do: nil

  defp validate_recipients([recipient | tail]) do
    case recipient do
      {name, address} when is_binary(name) and is_binary(address) ->
        validate_recipients(tail)

      address when is_binary(address) ->
        validate_recipients(tail)

      other ->
        raise ArgumentError,
          message: """
          The recipient `#{inspect(other)}` is invalid.

          Recipients must be in the format of either a string,
          or a tuple with two elements `{name, address}`
          """
    end
  end
end
