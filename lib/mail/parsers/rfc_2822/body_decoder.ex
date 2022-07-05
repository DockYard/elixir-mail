defmodule Mail.Parsers.RFC2822.BodyDecoder do
  @callback decode(body :: binary, Mail.Message.t()) :: binary
end
