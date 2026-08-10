# Third-party notices

Swift-TE implements patch formats first reverse-engineered by two other
open source projects. No code from either project is copied here — this
is an independent Swift implementation — but the format knowledge (chunk
layouts, JSON schemas, default patch values, unit conversions) comes
directly from their work, and neither format is documented anywhere else.

## teoperator

https://github.com/schollz/teoperator

MIT License, Copyright (c) 2020 Zack.

Source of the OP-1/OP-Z AIFF `APPL`/`op-1` chunk format, the synth and
drum patch JSON schemas, and the SAMPLECONVERSION sample-offset encoding.

The files under `Tests/TEOP1Tests/Fixtures/` are copied directly from
teoperator's own test fixtures and are used here as decode targets.

## op-patchstudio

https://github.com/joseph-holland/op-patchstudio

MIT License, Copyright (c) 2025 Joseph Holland. Portions Copyright (c)
2025 Brandon Withrow.

Source of the OP-XY preset JSON schema, region generation logic, and the
percent-to-internal-unit value conversions.
