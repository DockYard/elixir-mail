# Changelog

## Master

* Add DateTime and time zone support to date parsing/rendering
* Fix compile warnings

## 0.2.3 2021-06-28

* Add support for incorrect case in date parsing https://github.com/DockYard/elixir-mail/pull/132
* Support quoted-printable encoding in message headers https://github.com/DockYard/elixir-mail/pull/131

## 0.2.2 2020-07-28

* Documentation updates
* Handle parsing a recipient name which is an email address https://github.com/DockYard/elixir-mail/pull/123
* Add charset option to text, html part https://github.com/DockYard/elixir-mail/pull/122
* Add support for custom headers on attachments https://github.com/DockYard/elixir-mail/pull/120
* Add support for part without body https://github.com/DockYard/elixir-mail/pull/115
* Add support for multiple values in the content-type header in Mail.get_text https://github.com/DockYard/elixir-mail/pull/108
* Fix for #105 where put_text/2 would replace plain text attachment https://github.com/DockYard/elixir-mail/pull/106
* RFC2822 parse recipient value is now part of public API https://github.com/DockYard/elixir-mail/pull/104
* Various fixes for bugs found in parsing real email https://github.com/DockYard/elixir-mail/pull/100
* Various fixes for handling dates in headers
* Update parsing Received header to handle invalid/missing date part https://github.com/DockYard/elixir-mail/pull/96
* Add allowance for optional seconds and handle invalid hour in time https://github.com/DockYard/elixir-mail/pull/95
* Fix loop in Mail.Renderers.RFC2822.render_header/2 https://github.com/DockYard/elixir-mail/pull/93
* Fix invalid base64 encoding which broke in earlier version of Erlang https://github.com/DockYard/elixir-mail/pull/91
* Add support the Encoded Word RFC 2047 https://github.com/DockYard/elixir-mail/pull/90
* Retail all "received" headers https://github.com/DockYard/elixir-mail/pull/89

## 0.2.1 2019-03-02

* Fix quoted-printable encoding https://github.com/DockYard/elixir-mail/pull/83
* Optimized quoted-printable encoder to reduce memory usage https://github.com/DockYard/elixir-mail/pull/87
* Update RFC2822 email regex with a better one https://github.com/DockYard/elixir-mail/pull/86

## 0.2.0 2017-07-21

* Breaking - All message props are now binaries https://github.com/DockYard/elixir-mail/pull/69
* removed `Mail.Message.has_attachment?` and `Mail.Message.has_text_part?` https://github.com/DockYard/elixir-mail/pull/74
* added `Mail.has_attachments?` and `Mail.has_text_parts?` https://github.com/DockYard/elixir-mail/pull/74
* added `Mail.get_attachments` https://github.com/DockYard/elixir-mail/pull/75
* Allow RFC2822 email regex to be overridden by config https://github.com/DockYard/elixir-mail/pull/73
* Allow `Mail.put_attachment` to use in-memory data in tuple https://github.com/DockYard/elixir-mail/pull/58
* Support obsolete timestamps https://github.com/DockYard/elixir-mail/pull/70
* Fix test suite for Elixir 1.4+ https://github.com/DockYard/elixir-mail/pull/67

## 0.1.1 2016-10-12

* Moved API to using strings instead of atoms
* Parser and Renderer should handle reply-to header

## 0.1.0 2016-07-31

* API is stable enough for a minor version release
* Resolved Elixir 1.3 warnings

## 0.0.3 2016-03-14

* Began multipart support. The `Mail` struct can have multiple "parts".
  Each `Mail.Part` can have multiple "parts".
* Added RFC2822 Renderer
* Added RFC2822 Parser
