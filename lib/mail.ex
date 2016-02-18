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
  Add a plaintext part to the message

  Shortcut function for adding plain text part

      Mail.put_text(%Mail.Message{}, "Some plain text")

  If a text part already exists this function will replace that existing
  part with the new part.
  """
  def put_text(%Mail.Message{multipart: true} = message, body) do
    message= case Enum.find(message.parts, &Mail.Message.match_content_type?(&1, "text/plain")) do
      %Mail.Message{} = part -> Mail.Message.delete_part(message, part)
      _ -> message
    end

    Mail.Message.put_part(message, Mail.Message.build_text(body))
  end

  def put_text(%Mail.Message{} = message, body) do
    Mail.Message.put_body(message, body)
    |> Mail.Message.put_content_type("text/plain")
  end

  @doc """
  Add an HTML part to the message

      Mail.put_html(%Mail.Message{}, "<span>Some HTML</span>")

  If a text part already exists this function will replace that existing
  part with the new part.
  """
  def put_html(%Mail.Message{multipart: true} = message, body) do
    message= case Enum.find(message.parts, &Mail.Message.match_content_type?(&1, "text/html")) do
      %Mail.Message{} = part -> Mail.Message.delete_part(message, part)
      _ -> message
    end

    Mail.Message.put_part(message, Mail.Message.build_html(body))
  end

  def put_html(%Mail.Message{} = message, body) do
    Mail.Message.put_body(message, body)
    |> Mail.Message.put_content_type("text/html")
  end

  @doc """
  Add an attachment part to the message

      Mail.put_attachment(%Mail.Message{}, "README.md")

  Each call will add a new attachment part.
  """
  def put_attachment(%Mail.Message{multipart: true} = message, path) when is_binary(path),
    do: Mail.Message.put_part(message, Mail.Message.build_attachment(path))

  def put_attachment(%Mail.Message{} = message, path) when is_binary(path),
    do: Mail.Message.put_attachment(message, path)

  @doc """
  Add a new `subject` header

      Mail.put_subject(%Mail.Message{}, "Welcome to DockYard!")
      %Mail.Message{headers: %{subject: "Welcome to DockYard!"}}
  """
  def put_subject(message, subject),
    do: Mail.Message.put_header(message, :subject, subject)

  @doc """
  Add new recipients to the `to` header

  Recipients can be added as a single string or a list of strings.
  The list of recipients will be concated to the previous value.

      Mail.put_to(%Mail.Message{}, "one@example.com")
      %Mail.Message{headers: %{to: ["one@example.com"]}}

      Mail.put_to(%Mail.Message{}, ["one@example.com", "two@example.com"])
      %Mail.Message{headers: %{to: ["one@example.com", "two@example.com"]}}

      Mail.put_to(%Mail.Message{}, "one@example.com")
      |> Mail.put_to(["two@example.com", "three@example.com"])
      %Mail.Message{headers: %{to: ["one@example.com", "two@example.com", "three@example.com"]}}

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
    Mail.Message.put_header(message, :to, (message.headers[:to] || []) ++ recipients)
  end

  def put_to(message, recipient),
    do: put_to(message, [recipient])

  @doc """
  Add new recipients to the `cc` header

  Recipients can be added as a single string or a list of strings.
  The list of recipients will be concated to the previous value.

      Mail.put_cc(%Mail.Message{}, "one@example.com")
      %Mail.Message{headers: %{cc: ["one@example.com"]}}

      Mail.put_cc(%Mail.Message{}, ["one@example.com", "two@example.com"])
      %Mail.Message{headers: %{cc: ["one@example.com", "two@example.com"]}}

      Mail.put_cc(%Mail.Message{}, "one@example.com")
      |> Mail.put_cc(["two@example.com", "three@example.com"])
      %Mail.Message{headers: %{cc: ["one@example.com", "two@example.com", "three@example.com"]}}

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
    Mail.Message.put_header(message, :cc, (message.headers[:cc] || []) ++ recipients)
  end

  def put_cc(message, recipient),
    do: put_cc(message, [recipient])

  @doc """
  Add new recipients to the `bcc` header

  Recipients can be added as a single string or a list of strings.
  The list of recipients will be concated to the previous value.

      Mail.put_bcc(%Mail.Message{}, "one@example.com")
      %Mail.Message{headers: %{bcc: ["one@example.com"]}}

      Mail.put_bcc(%Mail.Message{}, ["one@example.com", "two@example.com"])
      %Mail.Message{headers: %{bcc: ["one@example.com", "two@example.com"]}}

      Mail.put_bcc(%Mail.Message{}, "one@example.com")
      |> Mail.put_bcc(["two@example.com", "three@example.com"])
      %Mail.Message{headers: %{bcc: ["one@example.com", "two@example.com", "three@example.com"]}}

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
    Mail.Message.put_header(message, :bcc, (message.headers[:bcc] || []) ++ recipients)
  end

  def put_bcc(message, recipient),
    do: put_bcc(message, [recipient])

  @doc """
  Add a new `from` header

      Mail.put_from(%Mail.Message{}, "user@example.com")
      %Mail.Message{headers: %{from: "user@example.com"}}
  """
  def put_from(message, sender),
    do: Mail.Message.put_header(message, :from, sender)

  @doc """
  Add a new `reply-to` header

      Mail.put_reply_to(%Mail.Message{}, "user@example.com")
      %Mail.Message{headers: %{reply_to: "user@example.com"}}
  """
  def put_reply_to(message, reply_address),
    do: Mail.Message.put_header(message, :reply_to, reply_address)

  @doc """
  Returns a unique list of all recipients

  Will collect all recipients from `to`, `cc`, and `bcc`
  and returns a unique list of recipients.
  """
  def all_recipients(message) do
    List.wrap(message.headers[:to]) ++
    List.wrap(message.headers[:cc]) ++
    List.wrap(message.headers[:bcc])
    |> Enum.uniq()
  end

  defp validate_recipients([]), do: nil
  defp validate_recipients([recipient|tail]) do
    case recipient do
      {name, address} when is_binary(name) and is_binary(address) -> validate_recipients(tail)
      address when is_binary(address) -> validate_recipients(tail)
      other -> raise ArgumentError,
        message: """
        The recipient `#{inspect other}` is invalid.

        Recipients must be in the format of either a string,
        or a tuple with two elements `{name, address}`
        """
    end
  end
end
