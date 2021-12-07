# Changelog

## 0.6.0

- Add `:odd` and `:even` to `:row_style` on table with a lower precedence than indexed styles
- Fix bug where only the first non-WinAnsi character was replaced [#32]

## 0.5.0

- Catch errors raised within the GenServer and re-raise them in the calling process

## 0.4.0

- Add `:encoding_replacement_character` option to supply a replacement character when encoding fails
- Add `:allow_row_overflow` option to `Pdf.table/4` to allow row contents to be split across pages

## 0.3.7

- Bug fix: Fix memory leak by stopping internal processes

## 0.3.6

- Bug fix: Correctly handle encoded text as binary, not UTF-8 encoded string
- Bug fix: External fonts now work like built-in fonts #17
- Bug fix: Reset colours changed by attributed text
- Bug fix: Fix global options for text_at/4 when using a string #11

## 0.3.5

- Deprecate: `Pdf.delete/1` in favour of `Pdf.cleanup/1`
- Deprecate: `Pdf.open/2` in favour of `Pdf.build/2`
