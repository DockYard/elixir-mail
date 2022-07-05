defmodule Mail.RFC2822BodyDecoderProxy do
  use Agent

  @behaviour Mail.Parsers.RFC2822.BodyDecoder

  @strict_impl Mail.Parsers.RFC2822.BodyDecoder.Strict
  @permissive_impl Mail.Parsers.RFC2822.BodyDecoder.Permissive

  def start_link(impl \\ @strict_impl), do: Agent.start_link(fn -> impl end, name: __MODULE__)

  def strict_impl, do: Agent.update(__MODULE__, fn _ -> @strict_impl end)
  def permissive_impl, do: Agent.update(__MODULE__, fn _ -> @permissive_impl end)

  @impl true
  def decode(body, message), do: Agent.get(__MODULE__, & &1).decode(body, message)
end
