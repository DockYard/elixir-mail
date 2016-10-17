defmodule Pdf do
  def new, do: {:ok, :eg_pdf.new}
  def new(func) do
    {:ok, pid} = new
    result = func.(pid)
    stop(pid)
    result
  end

  def points(x), do: x
  def picas(x),  do: x * 6
  def inches(x), do: round(x * 72.21)
  def cm(x),     do: round((x * 72.21) / 2.54)

  def white, do: {255, 255, 255}
  def black, do: {0, 0, 0}

  def text(pid, func) when is_function(func) do
    begin_text(pid)
    func.(pid)
    end_text(pid)
    pid
  end
  def text(pid, str) when is_binary(str) do
    :ok = :eg_pdf.text(pid, String.to_char_list(str))
    pid
  end

  def textbr(pid, text) when is_binary(text) do
    :ok = :eg_pdf.textbr(pid, String.to_char_list(text))
    pid
  end

  def get_string_width(pid, font_name, size, str) do
    :eg_pdf.get_string_width(pid, String.to_char_list(font_name), size, String.to_char_list(str))
  end

  def set_font(pid, name, size) do
    :ok = :eg_pdf.set_font(pid, String.to_char_list(name), size)
    pid
  end

  def text_at(pid, x, y, str) do
    :ok = :eg_pdf_lib.moveAndShow(pid, x, y, String.to_char_list(str))
    pid
  end

  def lines(pid, x, y, line_height, list) do
    print_lines(pid, x, y, line_height, list)
    pid
  end

  defp print_lines(_pid, _x, _y, _line_height, []), do: nil
  defp print_lines(pid, x, y, line_height, [line | tail]) do
    text_at(pid, x, y, line)
    print_lines(pid, x, y - line_height, line_height, tail)
  end

  def export(pid) do
    {doc, _} = :eg_pdf.export(pid)
    doc
  end
  def export!(pid, path, options \\ [:write, :binary]) do
    doc = export(pid)
    File.write!(path, doc, options)
  end
  def stop(pid), do: :eg_pdf.delete(pid)

  @methods [
    begin_text: 1,
    end_text: 1,
    save_state: 1,
    restore_state: 1,
    set_author: 2,
    set_title: 2,
    set_producer: 2,
    set_creator: 2,
    set_subject: 2,
    set_keywords: 2,
    set_page: 2,
    set_pagesize: 2,
    set_dash: 2,
    set_line_width: 2,
    set_fill_color: 2,
    set_stroke_color: 2,
    path: 2,
    set_text_pos: 3,
    rectangle: 3,
    image: 4,
    line: 5,
  ]

  Enum.each(@methods, fn
    ({name, 1}) ->
      def unquote(name)(pid) do
        :ok = :eg_pdf.unquote(name)(pid)
        pid
      end

    ({name, 2}) ->
      def unquote(name)(pid, a1) do
        :ok = :eg_pdf.unquote(name)(pid, a1)
        pid
      end

    ({name, 3}) ->
      def unquote(name)(pid, a1, a2) do
        :ok = :eg_pdf.unquote(name)(pid, a1, a2)
        pid
      end

    ({name, 4}) ->
      def unquote(name)(pid, a1, a2, a3) do
        :ok = :eg_pdf.unquote(name)(pid, a1, a2, a3)
        pid
      end

    ({name, 5}) ->
      def unquote(name)(pid, a1, a2, a3, a4) do
        :ok = :eg_pdf.unquote(name)(pid, a1, a2, a3, a4)
        pid
      end
  end)

  @lint false
  def print_grid(pdf) do
    [pdfc, _stream] = :gen_server.call(pdf, {:get_state})
    {x, y, width, height} = elem(pdfc, 8)
    pdf
    |> set_line_width(0.1)
    |> set_fill_color({127, 127, 127})
    |> set_font("Helvetica", 8)
    |> set_stroke_color({127, 127, 127})
    |> print_horizontal_lines(y, width, cm(0.5), height, fn(pdf, at) ->
      if at > 0 && rem(at, cm(1)) == 0 do
        pdf |> text_at(4, at, "#{div(at, cm(1))}cm")
      else
        pdf
      end
    end)
    |> print_vertical_lines(x, height, cm(0.5), width, fn(pdf, at) ->
      if at > 0 && rem(at, cm(1)) == 0 do
        pdf |> text_at(at - 8, 4, "#{div(at, cm(1))}cm") |> text_at(at - 8, height - 4 - 8, "#{div(at, cm(1))}cm")
      else
        pdf
      end
    end)
    pdf
  end

  @lint false
  defp print_horizontal_lines(pdf, at, _width, _step, last, _func) when at >= last or at < 0, do: pdf
  defp print_horizontal_lines(pdf, at, width, step, last, func) do
    pdf
    |> line(0, at, width, at)
    |> path(:stroke)
    |> func.(at)
    |> print_horizontal_lines(at + step, width, step, last, func)
  end

  @lint false
  defp print_vertical_lines(pdf, at, _height, _step, last, _func) when at >= last or at < 0, do: pdf
  defp print_vertical_lines(pdf, at, height, step, last, func) do
    pdf
    |> line(at, 0, at, height)
    |> path(:stroke)
    |> func.(at)
    |> print_vertical_lines(at + step, height, step, last, func)
  end
end
