defmodule Pdf.Examples.GeneralDocumentTest do
  use Pdf.Case, async: true

  @open true
  test "generate document" do
    file_path = output("general_document.pdf")

    {:ok, pdf} = Pdf.new(size: :a4, compress: false)

    %{width: width, height: height} = Pdf.size(pdf)

    pdf
    |> Pdf.set_info(
      title: "Test Document",
      producer: "Test producer",
      creator: "Test Creator",
      created: ~D"2020-03-17",
      modified: Date.utc_today(),
      author: "Test Author",
      subject: "Test Subject"
    )
    |> add_header("Lorem ipsum dolor sit amet", width, height)
    |> write_paragraphs1(width)
    |> write_paragraphs2(width)
    |> Pdf.write_to(file_path)
    |> Pdf.delete()

    if @open, do: System.cmd("open", ["-g", file_path])
  end

  defp add_header(pdf, header, width, height) do
    {pdf, ""} =
      pdf
      |> Pdf.set_font("Helvetica", 16, bold: true)
      |> Pdf.text_wrap({20, height - 40}, {width - 40, 20}, header, align: :center)

    Pdf.move_down(pdf, 16)
  end

  defp write_paragraphs1(pdf, width) do
    cursor = Pdf.cursor(pdf)

    text = """
    Lorem ipsum dolor sit amet, consectetur adipiscing elit. Suspendisse elementum enim metus, quis posuere sem molestie interdum. Ut efficitur odio lectus, uty facilisis odio tempor quis. Ut ut risus quis tellus placerat tristique ut ultrices leo. Etiam ante lacus, pulvinar non aliquam luctus, efficitur vel velit. Aenean nec urna metus. Sed aliquam libero ligula, ac commodo turpis pulvinar sed. Aenean interdum elementum tempor. Cras tempus feugiat consequat. Mauris ut nulla et orci dapibus auctor a sit amet odio. Vivamus sit amet mi libero. Fusce a neque sagittis, volutpat ligula sed, eleifend felis. Ut luctus metus justo, id porta dui dignissim vitae. Duis sit amet maximus justo, non finibus quam. Orci varius natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Nulla ultrices diam nec vulputate congue. Duis ornare pulvinar nulla. Sed at justo nec tortor efficitur dapibus ac non enim. Nam sed finibus odio, ac pretium mi. In mattis viverra cursus. Integer a risus sagittis tortor eleifend sollicitudin. Nullam fermentum maximus odio at laoreet. Maecenas malesuada sagittis aliquet.

    Vivamus sodales eros eu auctor imperdiet. Praesent sit amet nibh sollicitudin, tincidunt est ac, auctor tortor. Nunc ipsum massa, pharetra id sem id, convallis malesuada orci. Donec consequat id metus a mollis. Fusce luctus nisi ipsum. Cras id magna hendrerit, facilisis lorem vitae, pellentesque diam. Morbi imperdiet suscipit turpis et pulvinar. Nam convallis sit amet nibh sit amet condimentum. Donec sit amet neque eget tortor ultrices dignissim. Mauris ac justo convallis, ultricies arcu a, auctor elit. Suspendisse facilisis vulputate pharetra. Sed in malesuada neque. Fusce sed sodales lectus.
    """

    padding = 20
    image_width = 100
    image_height = 75
    image_margin = 10

    {pdf, remaining} =
      pdf
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.add_image({padding, cursor - image_height}, fixture("rgb.jpg"))
      |> Pdf.text_wrap(
        {padding + image_width + image_margin, cursor - image_height - image_margin},
        {width - padding * 2 - image_width - image_margin, image_height + image_margin},
        text
      )

    cursor = Pdf.cursor(pdf)

    {pdf, ""} =
      pdf
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.text_wrap({padding, padding}, {width - padding * 2, cursor - padding}, remaining)

    Pdf.move_down(pdf, 12)
  end

  defp write_paragraphs2(pdf, width) do
    cursor = Pdf.cursor(pdf)

    text = """
    Etiam fermentum molestie diam vitae consequat. Etiam vitae arcu orci. Curabitur at feugiat mauris. Vestibulum ultrices ipsum dolor, ac fringilla nibh suscipit eget. Donec convallis leo sit amet euismod convallis. Fusce id dui fermentum velit venenatis facilisis. Sed eleifend eget tellus vel dictum. Donec nec nibh quis ex elementum fringilla volutpat in dui. Nunc porta luctus turpis, vel eleifend sapien bibendum faucibus. Cras malesuada sit amet neque sit amet varius.

    Praesent eget lacinia arcu. Quisque vitae nisl consectetur, ullamcorper leo id, elementum erat. Quisque eget ullamcorper orci. Curabitur dignissim dui et posuere tempus. Ut sagittis sollicitudin hendrerit. Aenean mollis tincidunt tortor, a ultrices justo euismod accumsan. Cras tincidunt quis ante id luctus. Donec rhoncus sodales nisl sed sagittis. Curabitur convallis purus eu aliquet venenatis. Aliquam dignissim massa in consectetur facilisis. Fusce hendrerit ullamcorper dui non consectetur. Proin lobortis nulla quis elit varius, vitae egestas tortor lobortis. Ut id scelerisque ligula, tristique gravida sem. Sed vitae varius massa. Donec ac eros sapien.
    """

    padding = 20

    {pdf, ""} =
      pdf
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.text_wrap({padding, padding}, {width - padding * 2, cursor - padding}, text)

    Pdf.move_down(pdf, 12)
  end
end
