# Upgrade guide: ordered, multi-valued headers

This release changes how `Mail.Message` stores and exposes headers so repeated headers (e.g. `Received`) are preserved.

## Summary of changes

- **Headers are no longer stored in a map.**
  - `Mail.Message.headers` is now a `%Mail.Headers{}` that stores headers as an **ordered list** of `{name, value}` pairs.
  - Header names are stored **lowercase** and `_` is normalized to `-`.

- **Reading all header instances**
  - `Mail.Message.get_header/2` now **always returns a list** of all header values for that name (in stored order).

- **Reading a singleton header**
  - `Mail.Message.get_header!/2` returns the single header value or `nil`, and **raises** if there are multiple values.

- **Writing headers**
  - `Mail.Message.put_header/3` **replaces all instances** of that header name with the new value.
  - `Mail.Message.prepend_header/3` **adds** a new header instance (duplicates allowed) at the beginning.

- **`Mail.get_*` getters remain scalar**
  - `Mail.get_subject/1`, `Mail.get_from/1`, `Mail.get_to/1`, etc. still return a scalar by selecting the **first** header instance.
  - New strict variants like `Mail.get_subject!/1`, `Mail.get_from!/1`, etc. return the single value or `nil`, and **raise** on duplicates.

## Common code changes

### Direct map access on `headers`

**Before**

```elixir
message.headers["subject"]
Map.has_key?(message.headers, "bcc")
```

**After**

```elixir
# `headers[...]` still works (via Access):
# - returns `nil` when missing
# - returns the single value when exactly one header exists
# - returns a list of values when multiple headers exist
message.headers["subject"]

# Prefer explicit helpers when you want a specific contract:
Mail.Message.has_header?(message, "bcc")
```

### Getting all header instances

**Before (single value or special-cased in a map)**

```elixir
received = message.headers["received"]
```

**After**

```elixir
received_values = Mail.Message.get_header(message, "received")
```

### Getting a singleton header safely

**Before**

```elixir
content_type = message.headers["content-type"]
```

**After**

```elixir
content_type = Mail.Message.get_header!(message, "content-type")
```

### Pattern matches on headers

**Before**

```elixir
%Mail.Message{headers: %{"content-type" => ["text/plain" | _]}} = part
```

**After**

```elixir
["text/plain" | _] = Mail.Message.get_header!(part, "content-type")
```

## Notes

- If you were previously depending on implicit ordering from maps, you should now rely on the explicit **header insertion order**.
- If you need to preserve duplicates when copying headers, avoid converting to a map (which collapses duplicates).

