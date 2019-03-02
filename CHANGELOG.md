# Versions

## 0.2.2

* Fix quoted-printable encoding https://github.com/DockYard/elixir-mail/pull/83
* Optimized quoted-printable encoder to reduce memory usage https://github.com/DockYard/elixir-mail/pull/87
* Update RFC2822 email regex with a better one https://github.com/DockYard/elixir-mail/pull/86

## 0.2.0

* Breaking - All message props are now binaries https://github.com/DockYard/elixir-mail/pull/69
* removed `Mail.Message.has_attachment?` and `Mail.Message.has_text_part?` https://github.com/DockYard/elixir-mail/pull/74
* added `Mail.has_attachments?` and `Mail.has_text_parts?` https://github.com/DockYard/elixir-mail/pull/74
* added `Mail.get_attachments` https://github.com/DockYard/elixir-mail/pull/75
* Allow RFC2822 email regex to be overriden by config https://github.com/DockYard/elixir-mail/pull/73
* Allow `Mail.put_attachment` to use in-memory data in tuple https://github.com/DockYard/elixir-mail/pull/58
* Support obsolete timestamps https://github.com/DockYard/elixir-mail/pull/70
* Fix test suite for Elixir 1.4+ https://github.com/DockYard/elixir-mail/pull/67

## 0.1.1

* Moved API to using strings instead of atoms
* Parser and Renderer should handle reply-to header

## 0.1.0

* API is stable enough for a minor version release
* Resolved Elixir 1.3 warnings

## 0.0.3

* Began multipart support. The `Mail` struct can have multiple "parts".
  Each `Mail.Part` can have multiple "parts".
* Added RFC2822 Renderer
* Added RFC2822 Parser
