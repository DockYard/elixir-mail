# Changelog

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
