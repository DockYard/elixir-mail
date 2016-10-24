defmodule Pdf.Case do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Pdf.Case
    end
  end

  def fixture(path),
    do: __DIR__ |> Path.join("fixtures") |> Path.join(path)
end
