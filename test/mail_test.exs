defmodule MailTest do
  use ExUnit.Case
  doctest Mail

  test "put_subject" do
    mail = Mail.put_subject(%Mail{}, "test subject")
    assert mail.subject == "test subject"
  end

  test "put_body" do
    mail = Mail.put_body(%Mail{}, "test body")
    assert mail.body == "test body"
  end

  test "put_to when single recipient" do
    mail = Mail.put_to(%Mail{}, "user@example.com")
    assert mail.to == ["user@example.com"]
  end

  test "put_to when multiple recipients" do
    mail = Mail.put_to(%Mail{}, ["one@example.com", "two@example.com"])
    assert mail.to == ["one@example.com", "two@example.com"]
  end

  test "composing multiple `to` recipients" do
    mail =
      Mail.put_to(%Mail{}, "user@example.com")
      |> Mail.put_to(["one@example.com", "two@example.com"])

    assert mail.to == ["user@example.com",
                       "one@example.com",
                       "two@example.com"]
  end

  test "put_from" do
    mail = Mail.put_from(%Mail{}, "user@example.com")
    assert mail.from == "user@example.com"
  end

  test "put_reply_to" do
    mail = Mail.put_reply_to(%Mail{}, "other@example.com")
    assert mail.reply_to == "other@example.com"
  end

  test "put_cc when single recipient" do
    mail = Mail.put_cc(%Mail{}, "user@example.com")
    assert mail.cc == ["user@example.com"]
  end

  test "put_cc when multiple recipients" do
    mail = Mail.put_cc(%Mail{}, ["one@example.com", "two@example.com"])
    assert mail.cc == ["one@example.com", "two@example.com"]
  end

  test "composing multiple `cc` recipients" do
    mail =
      Mail.put_cc(%Mail{}, "user@example.com")
      |> Mail.put_cc(["one@example.com", "two@example.com"])

    assert mail.cc == ["user@example.com",
                       "one@example.com",
                       "two@example.com"]
  end

  test "put_bcc when single recipient" do
    mail = Mail.put_bcc(%Mail{}, "user@example.com")
    assert mail.bcc == ["user@example.com"]
  end

  test "put_bcc when multiple recipients" do
    mail = Mail.put_bcc(%Mail{}, ["one@example.com", "two@example.com"])
    assert mail.bcc == ["one@example.com", "two@example.com"]
  end

  test "composing multiple `bcc` recipients" do
    mail =
      Mail.put_bcc(%Mail{}, "user@example.com")
      |> Mail.put_bcc(["one@example.com", "two@example.com"])

    assert mail.bcc == ["user@example.com",
                       "one@example.com",
                       "two@example.com"]
  end
end
