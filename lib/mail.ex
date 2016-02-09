defmodule Mail do
  defstruct body: "",
            headers: %{}

  def put_body(mail, body),
    do: put_in(mail.body, body)

  def put_header(mail, key, content),
    do: put_in(mail.headers[key], content)

  def put_subject(mail, subject),
    do: put_header(mail, :subject, subject)

  def put_to(mail, recipient) when is_binary(recipient),
    do: put_to(mail, [recipient])

  def put_to(mail, recipients) when is_list(recipients),
    do: put_header(mail, :to, (mail.headers[:to] || []) ++ recipients)

  def put_cc(mail, recipient) when is_binary(recipient),
    do: put_cc(mail, [recipient])

  def put_cc(mail, recipients) when is_list(recipients),
    do: put_header(mail, :cc, (mail.headers[:cc] || []) ++ recipients)

  def put_bcc(mail, recipient) when is_binary(recipient),
    do: put_bcc(mail, [recipient])

  def put_bcc(mail, recipients) when is_list(recipients),
    do: put_header(mail, :bcc, (mail.headers[:bcc] || []) ++ recipients)

  def put_from(mail, sender),
    do: put_header(mail, :from, sender)

  def put_reply_to(mail, reply_address),
    do: put_header(mail, :reply_to, reply_address)

  def put_content_type(mail, content_type),
    do: put_header(mail, :content_type, content_type)

  def all_recipients(mail) do
    List.wrap(mail.headers[:to]) ++
    List.wrap(mail.headers[:cc]) ++
    List.wrap(mail.headers[:bcc])
    |> Enum.uniq()
  end
end
