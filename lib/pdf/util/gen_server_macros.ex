defmodule Pdf.Util.GenServerMacros do
  @moduledoc false
  @doc false
  defmacro defcall({name, _, args}, opts) do
    [state, from | args] = Enum.reverse(args)
    args = Enum.reverse(args)

    quote do
      def unquote(name)(pid, unquote_splicing(args)) do
        GenServer.call(pid, {unquote(name), unquote_splicing(args)}, 120_000)
      end

      defp unquote(:"do_#{name}")(unquote_splicing(args), unquote(from), unquote(state)) do
        unquote(opts[:do])
      end

      def handle_call({unquote(name), unquote_splicing(args)}, from, state) do
        unquote(:"do_#{name}")(unquote_splicing(args), from, state)
      end
    end
  end
end
