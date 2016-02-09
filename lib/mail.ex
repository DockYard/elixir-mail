defmodule Mail do
  defstruct subject: "",
            body: "",
            from: "",
            reply_to: nil,
            to: [],
            cc: [],
            bcc: []

  def put_subject(mail, subject),
    do: put_in(mail.subject, subject)

  def put_body(mail, body),
    do: put_in(mail.body, body)

  def put_from(mail, sender),
    do: put_in(mail.from, sender)

  def put_reply_to(mail, reply_address),
    do: put_in(mail.reply_to, reply_address)

  def put_to(mail, recipient) when is_binary(recipient),
    do: put_to(mail, [recipient])

  def put_to(mail, recipients) when is_list(recipients),
    do: put_in(mail.to, mail.to ++ recipients)

  def put_cc(mail, recipient) when is_binary(recipient),
    do: put_cc(mail, [recipient])

  def put_cc(mail, recipients) when is_list(recipients),
    do: put_in(mail.cc, mail.cc ++ recipients)

  def put_bcc(mail, recipient) when is_binary(recipient),
    do: put_bcc(mail, [recipient])

  def put_bcc(mail, recipients) when is_list(recipients),
    do: put_in(mail.bcc, mail.bcc ++ recipients)
end
