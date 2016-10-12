# Versions

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
