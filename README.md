# Mail [![Build Status](https://secure.travis-ci.org/DockYard/elixir-mail.svg?branch=master)](http://travis-ci.org/DockYard/elixir-mail)

An RFC2822 implementation in Elixir, built for composability.

**[Mail is built and maintained by DockYard, contact us for expert Elixir and Phoenix consulting](https://dockyard.com/phoenix-consulting)**.

## Installation

```elixir
def deps do
  # Get from hex
  [{:mail, "~> 0.2"}]
  # Or use the latest from master
  [{:mail, github: "DockYard/elixir-mail"}]
end
```

## Building

You can quickly build an RFC2822 spec compliant message.

#### Single-Part

```elixir
message =
  Mail.build()
  |> Mail.put_text("A great message")
  |> Mail.put_to("bob@example.com")
  |> Mail.put_from("me@example.com")
  |> Mail.put_subject("Open me")
```

#### Multi-Part

```elixir
message = 
  Mail.build_multipart()
  |> Mail.put_text("Hello there!")
  |> Mail.put_html("<h1>Hello there!</h1>")
  |> Mail.put_attachment("path/to/README.md")
  |> Mail.put_attachment({"README.md", file_data})
```

## Rendering

After you have built your message you can render it:

```elixir
rendered_message = Mail.Renderers.RFC2822.render(message)
```

## Parsing

If you'd like to parse an already rendered message back into 
a data model:

```elixir
Mail.Parsers.RFC2822.parse(rendered_message)
```

[There are more functions described in the docs](http://hexdocs.pm/mail/Mail.html)

## Authors ##

* [Brian Cardarella](http://twitter.com/bcardarella)

[We are very thankful for the many contributors](https://github.com/dockyard/elixir-mail/graphs/contributors)

## Versioning ##

This library follows [Semantic Versioning](http://semver.org)

## Looking for help with your Elixir project? ##

[At DockYard we are ready to help you build your next Elixir project](https://dockyard.com/phoenix-consulting). We have a unique expertise 
in Elixir and Phoenix development that is unmatched. [Get in touch!](https://dockyard.com/contact/hire-us)

At DockYard we love Elixir! You can [read our Elixir blog posts](https://dockyard.com/blog/categories/elixir)
or come visit us at [The Boston Elixir Meetup](http://www.meetup.com/Boston-Elixir/) that we organize.

## Want to help? ##

Please do! We are always looking to improve this library. Please see our
[Contribution Guidelines](https://github.com/dockyard/elixir-mail/blob/master/CONTRIBUTING.md)
on how to properly submit issues and pull requests.

## Legal ##

[DockYard](http://dockyard.com/), Inc. &copy; 2015

[@dockyard](http://twitter.com/dockyard)

[Licensed under the MIT license](http://www.opensource.org/licenses/mit-license.php)
