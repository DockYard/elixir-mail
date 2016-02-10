defmodule Mail do
  defstruct body: %{},
            headers: %{}

  @moduledoc """
  Mail primitive for composing messages.

  Build a mail message with the `Mail` struct

      mail =
        Mail.build
        |> Mail.put_subject("How is it going?")
        |> Mail.put_text("Just checking in")
        |> Mail.put_to("joe@example.com")
        |> Mail.put_from("brian@example.com")

      %Mail{body: %{text: "Just checking in",
            headers: %{subject: "How is it going?",
                       to: ["joe@example.com"],
                       from: "brian@example.com"}}
  """

  @doc """
  Builds empty mail struct for further composing

      Mail.build()
  """
  def build,
    do: %Mail{}

  @doc """
  Add content to the body by mimetype as a key/value pair

  Allows content to be updated in the `body` field
  by the mimetype extension

      Mail.put_put(%Mail{}, :text, "text content")
  """
  def put_body(mail, part, content),
    do: put_in(mail.body[part], content)

  @doc """
  Add text content to the body

  Shortcut function for adding plain text to the body

      Mail.put_text(%Mail{}, "Some plain text")

  This function is equivilant to using the `put_body/3`
  function

      Mail.put_body(%Mail{}, :text, "Some plain text")
  """
  def put_text(mail, content),
    do: put_body(mail, :text, content)

  @doc """
  Add html content to the body

  Shortcut function for adding html to the body

      Mail.put_html(%Mail{}, "<span>Some HTML</span>")

  This function is equivilant to using the `put_body/3`
  function

      Mail.put_body(%Mail{}, :html, "<span>Some HTML</span>")
  """
  def put_html(mail, content),
    do: put_body(mail, :html, content)

  @doc """
  Add a new header key/value pair

      Mail.put_header(%Mail{}, :subject, "Welcome to DockYard!")

  The individual headers will be in the `headers` field on the `%Mail{}` struct
  """
  def put_header(mail, key, content),
    do: put_in(mail.headers[key], content)

  @doc """
  Add a new `subject` header

      Mail.put_subject(%Mail, "Welcome to DockYard!")
      %Mail{headers: %{subject: "Welcome to DockYard!"}}
  """
  def put_subject(mail, subject),
    do: put_header(mail, :subject, subject)

  @doc """
  Add new recipients to the `to` header

  Recipients can be added as a single string or a list of strings.
  The list of recipients will be concated to the previous value.

      Mail.put_to(%Mail{}, "one@example.com")
      %Mail{headers: %{to: ["one@example.com"]}}

      Mail.put_to(%Mail{}, ["one@example.com", "two@example.com"])
      %Mail{headers: %{to: ["one@example.com", "two@example.com"]}}

      Mail.put_to(%Mail{}, "one@example.com")
      |> Mail.put_to(["two@example.com", "three@example.com"])
      %Mail{headers: %{to: ["one@example.com", "two@example.com", "three@example.com"]}}

  The value of a recipient must conform to either a string value or a tuple with two elements,
  otherwise an `ArgumentError` is raised.

  Valid forms:
  * `"user@example.com"`
  * `"Test User <user@example.com>"`
  * `{"Test User", "user@example.com"}`
  """
  def put_to(mail, recipients)

  def put_to(mail, recipients) when is_list(recipients) do
    validate_recipients(recipients)
    put_header(mail, :to, (mail.headers[:to] || []) ++ recipients)
  end

  def put_to(mail, recipient),
    do: put_to(mail, [recipient])

  @doc """
  Add new recipients to the `cc` header

  Recipients can be added as a single string or a list of strings.
  The list of recipients will be concated to the previous value.

      Mail.put_cc(%Mail{}, "one@example.com")
      %Mail{headers: %{cc: ["one@example.com"]}}

      Mail.put_cc(%Mail{}, ["one@example.com", "two@example.com"])
      %Mail{headers: %{cc: ["one@example.com", "two@example.com"]}}

      Mail.put_cc(%Mail{}, "one@example.com")
      |> Mail.put_cc(["two@example.com", "three@example.com"])
      %Mail{headers: %{cc: ["one@example.com", "two@example.com", "three@example.com"]}}

  The value of a recipient must conform to either a string value or a tuple with two elements,
  otherwise an `ArgumentError` is raised.

  Valid forms:
  * `"user@example.com"`
  * `"Test User <user@example.com>"`
  * `{"Test User", "user@example.com"}`
  """
  def put_cc(mail, recipients)

  def put_cc(mail, recipients) when is_list(recipients) do
    validate_recipients(recipients)
    put_header(mail, :cc, (mail.headers[:cc] || []) ++ recipients)
  end

  def put_cc(mail, recipient),
    do: put_cc(mail, [recipient])

  @doc """
  Add new recipients to the `bcc` header

  Recipients can be added as a single string or a list of strings.
  The list of recipients will be concated to the previous value.

      Mail.put_bcc(%Mail{}, "one@example.com")
      %Mail{headers: %{bcc: ["one@example.com"]}}

      Mail.put_bcc(%Mail{}, ["one@example.com", "two@example.com"])
      %Mail{headers: %{bcc: ["one@example.com", "two@example.com"]}}

      Mail.put_bcc(%Mail{}, "one@example.com")
      |> Mail.put_bcc(["two@example.com", "three@example.com"])
      %Mail{headers: %{bcc: ["one@example.com", "two@example.com", "three@example.com"]}}

  The value of a recipient must conform to either a string value or a tuple with two elements,
  otherwise an `ArgumentError` is raised.

  Valid forms:
  * `"user@example.com"`
  * `"Test User <user@example.com>"`
  * `{"Test User", "user@example.com"}`
  """
  def put_bcc(mail, recipients)

  def put_bcc(mail, recipients) when is_list(recipients) do
    validate_recipients(recipients)
    put_header(mail, :bcc, (mail.headers[:bcc] || []) ++ recipients)
  end

  def put_bcc(mail, recipient),
    do: put_bcc(mail, [recipient])

  @doc """
  Add a new `from` header

      Mail.put_from(%Mail, "user@example.com")
      %Mail{headers: %{from: "user@example.com"}}
  """
  def put_from(mail, sender),
    do: put_header(mail, :from, sender)

  @doc """
  Add a new `reply-to` header

      Mail.put_reply_to(%Mail, "user@example.com")
      %Mail{headers: %{reply_to: "user@example.com"}}
  """
  def put_reply_to(mail, reply_address),
    do: put_header(mail, :reply_to, reply_address)

  @doc """
  Add a new `content-type` header

      Mail.put_content_type(%Mail, "text/plain")
      %Mail{headers: %{content_type: "text/plain"}}
  """
  def put_content_type(mail, content_type),
    do: put_header(mail, :content_type, content_type)

  @doc """
  Returns a unique list of all recipients

  Will collect all recipients from `to`, `cc`, and `bcc`
  and returns a unique list of recipients.
  """
  def all_recipients(mail) do
    List.wrap(mail.headers[:to]) ++
    List.wrap(mail.headers[:cc]) ++
    List.wrap(mail.headers[:bcc])
    |> Enum.uniq()
  end

  @doc """
  Deletes a specific header key

      Mail.delete_header(%Mail{headers: %{subject: "Welcome to DockYard!"}}, :subject)
      %Mail{headers: %{}}
  """
  def delete_header(mail, header),
    do: put_in(mail.headers, Map.delete(mail.headers, header))

  @doc """
  Deletes a list of headers

      Mail.delete_headers(%Mail{headers: %{foo: "bar", baz: "qux"}}, [:foo, :baz])
      %Mail{headers: %{}}
  """
  def delete_headers(mail, headers)
  def delete_headers(mail, []), do: mail
  def delete_headers(mail, [header|tail]),
    do: delete_headers(delete_header(mail, header), tail)

  defp validate_recipients([]), do: nil
  defp validate_recipients([recipient|tail]) do
    case recipient do
      {name, email} -> validate_recipients(tail)
      email when is_binary(email) -> validate_recipients(tail)
      other -> raise ArgumentError,
        message: """
        The recipient `#{inspect other}` is invalid.

        Recipients must be in the format of either a string,
        or a tuple with two elements `{name, email}`
        """
    end
  end
end
