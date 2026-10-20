defmodule Mail.Renderers.TextAttachmentTest do
  use ExUnit.Case, async: true

  for filename <- ["notes.txt", "notes.html"] do
    test "keeps #{filename} attachments outside body alternatives" do
      filename = unquote(filename)

      message =
        Mail.build_multipart()
        |> Mail.put_text("Body text")
        |> Mail.put_html("<p>Body text</p>")
        |> Mail.put_attachment({filename, "Attachment contents"})
        |> Mail.render()
        |> Mail.parse()

      assert ["multipart/mixed" | _] = Mail.Message.get_content_type(message)
      assert [body, attachment] = message.parts
      assert ["multipart/alternative" | _] = Mail.Message.get_content_type(body)
      assert length(body.parts) == 2
      assert Mail.Message.is_attachment?(attachment)
      assert Mail.get_attachments(message) == [{filename, "Attachment contents"}]
    end
  end

  test "keeps inline text parts related to body alternatives" do
    message =
      Mail.build_multipart()
      |> Mail.put_text("Body text")
      |> Mail.put_html("<p>Body text</p>")
      |> Mail.put_attachment({"inline.txt", "Inline contents"},
        headers: [
          content_disposition: ["inline", {"filename", "inline.txt"}],
          content_id: "owned-inline"
        ]
      )
      |> Mail.render()
      |> Mail.parse()

    assert ["multipart/related" | _] = Mail.Message.get_content_type(message)
    assert [body, inline] = message.parts
    assert ["multipart/alternative" | _] = Mail.Message.get_content_type(body)
    assert length(body.parts) == 2
    assert Mail.Message.is_attachment?(inline, :inline)
    assert Mail.get_attachments(message, :inline) == [{"inline.txt", "Inline contents"}]
  end
end
