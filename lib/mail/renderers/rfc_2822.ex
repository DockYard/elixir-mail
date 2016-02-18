defmodule Mail.Renderers.RFC2822 do
  import Mail.Message, only: [match_content_type?: 2]
  @moduledoc """
  RFC2822 Parser

  Will attempt to render a valid RFC2822 message
  from a `%Mail.Message{}` data model.

      Mail.Renderers.RFC2822.render(message)
  """

  @doc """
  Renders a message according to the RFC2882 spec
  """
  def render(%Mail.Message{multipart: true} = message) do
    message = reorganize(message)
    headers = put_in(message.headers, [:mime_version], "1.0")

    Map.put(message, :headers, headers)
    |> render_part()
  end

  def render(%Mail.Message{} = message) do
    render_part(message)
  end

  @doc """
  Render an individual part
  """
  def render_part(message)
  def render_part(%Mail.Message{multipart: true} = message) do
    boundary = Mail.Message.get_boundary(message)
    message = Mail.Message.put_boundary(message, boundary)

    headers = render_headers(message.headers)
    boundary = "--#{boundary}"

    parts =
      render_parts(message.parts)
      |> Enum.join("\n\n#{boundary}\n")

    "#{headers}\n\n#{boundary}\n#{parts}\n#{boundary}--"
  end
  def render_part(%Mail.Message{} = message) do
    "#{render_headers(message.headers)}\n\n#{message.body}"
  end

  def render_parts(parts) when is_list(parts),
    do: Enum.map(parts, &render_part(&1))

  @doc """
  Will render a given header according to the RFC2882 spec
  """
  def render_header(key, value)
  def render_header(key, value) when is_atom(key),
    do: render_header(Atom.to_string(key), value)
  def render_header(key, value) do
    String.split(key, "_")
    |> Enum.map(&String.capitalize(&1))
    |> Enum.join("-")
    |> Kernel.<>(": ")
    |> Kernel.<>(render_header_value(key, value))
  end

  defp render_header_value("to", value) when is_list(value),
    do: Enum.join(value, ", ")
  defp render_header_value("to", value), do: value

  defp render_header_value(_key, [value | subtypes]),
    do: Enum.join([value | render_subtypes(subtypes)], "; ")
  defp render_header_value(key, value),
    do: render_header_value(key, List.wrap(value))

  defp render_subtypes([]), do: []
  defp render_subtypes([{key, value} | subtypes]) when is_atom(key),
    do: render_subtypes([{Atom.to_string(key), value} | subtypes])

  defp render_subtypes([{"boundary", value} | subtypes]) do
    [~s(boundary="#{value}") | render_subtypes(subtypes)]
  end
  defp render_subtypes([{key, value} | subtypes]) do
    key = String.replace(key, "_", "-")
    ["#{key}=#{value}" | render_subtypes(subtypes)]
  end

  @doc """
  Will render all headers according to the RFC2882 spec
  """
  def render_headers(headers)
  def render_headers(map) when is_map(map),
    do: Map.to_list(map)
        |> render_headers()
  def render_headers(list) when is_list(list) do
    do_render_headers(list)
    |> Enum.reverse()
    |> Enum.join("\n")
  end

  defp do_render_headers([]), do: []
  defp do_render_headers([{key, value} | headers]) do
    [render_header(key, value) | do_render_headers(headers)]
  end

  defp reorganize(%Mail.Message{multipart: true} = message) do
    content_type = Mail.Message.get_content_type(message)

    if Mail.Message.has_attachment?(message) do
      text_parts =
        Enum.filter(message.parts, &(match_content_type?(&1, ~r/text\/(plain|html)/)))
        |> Enum.sort(&(&1 > &2))

      content_type = List.replace_at(content_type, 0, "multipart/mixed")
      message = Mail.Message.put_content_type(message, content_type)

      if Enum.any?(text_parts) do
        message = Enum.reduce(text_parts, message, &(Mail.Message.delete_part(&2, &1)))
        mixed_part =
          Mail.build_multipart()
          |> Mail.Message.put_content_type("multipart/alternative")

        mixed_part = Enum.reduce(text_parts, mixed_part, &(Mail.Message.put_part(&2, &1)))
        put_in(message.parts, List.insert_at(message.parts, 0, mixed_part))
      end
    else
      content_type = List.replace_at(content_type, 0, "multipart/alternative")
      Mail.Message.put_content_type(message, content_type)
    end
  end
  defp reorganize(%Mail.Message{} = message), do: message
end
