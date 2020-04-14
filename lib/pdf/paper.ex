defmodule Pdf.Paper do
  [
    a0: [2380, 3368],
    a1: [1684, 2380],
    a2: [1190, 1684],
    a3: [842, 1190],
    a4: [595, 842],
    a5: [421, 595],
    a6: [297, 421],
    a7: [210, 297],
    a8: [148, 210],
    a9: [105, 148],
    b0: [2836, 4008],
    b1: [2004, 2836],
    b2: [1418, 2004],
    b3: [1002, 1418],
    b4: [709, 1002],
    b5: [501, 709],
    b6: [355, 501],
    b7: [250, 355],
    b8: [178, 250],
    b9: [125, 178],
    b10: [89, 125],
    c5e: [462, 649],
    comm10e: [298, 683],
    dle: [312, 624],
    executive: [542, 720],
    folio: [595, 935],
    ledger: [1224, 792],
    legal: [612, 1008],
    letter: [612, 792],
    tabloid: [792, 1224]
  ]
  |> Enum.each(fn {size, dimensions} ->
    def size(unquote(size)), do: [0, 0 | unquote(dimensions)]
    def size({unquote(size), :landscape}), do: [0, 0 | unquote(Enum.reverse(dimensions))]
  end)

  def size([_width, _height] = dimensions), do: [0, 0 | dimensions]
end
