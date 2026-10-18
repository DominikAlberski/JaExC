# JaExC — Japanese Exercise Creator

JaExC is a Ruby gem that creates Japanese kanji-reading exercises with a local open-weight model.
It runs inside your application through Ruby method calls.
It does not need Rails, a database, or an HTTP service.

JaExC validates the structure and the characters of each exercise.
JaExC does not prove that the Japanese is natural or that the translations are correct.
A teacher must review the exercises before use.

## Exercise types

- `:kanji_reading` generates sentences.
- `:kanji_words` generates dictionary words.

Each exercise contains Japanese text, its kana reading, translations, and the target kanji in the text.

## Setup

Requirements:

- Ruby 3.2 or later.
- An [Ollama](https://ollama.com) server with an open-weight model.

Add the gem from git:

```ruby
gem "jaexc", git: "https://github.com/<owner>/jaexc"
```

Pull a model on the Ollama server:

```bash
ollama pull <model>
```

## Public interface

```ruby
require "jaexc"

provider = JaExC::Providers::RubyLLM.new(
  provider: :ollama,
  model: "<model>",
  base_url: "http://localhost:11434/v1",
  timeout: 120,
  thinking: false
)

creator = JaExC::Creator.new(provider: provider)

result = creator.generate(
  exercise_type: :kanji_reading,
  target_kanji: ["学"],
  allowed_kanji: ["学", "校", "日", "本"],
  level: :N5,
  count: 5,
  translation_locales: [:en, :pl]
)

result.provider   # => :ollama
result.model      # => "<model>"
result.exercises.each do |exercise|
  exercise.jp            # => "学校に行きます。"
  exercise.reading       # => "がっこうにいきます。"
  exercise.translations  # => { en: "...", pl: "..." }
  exercise.target_kanji  # => ["学"]
end
```

`thinking: false` is the default. The adapter sends `reasoning_effort: "none"`.
With thinking on, Gemma 4 26B-A4B filled the 16384-token context with reasoning in 8 of 10 test calls
and returned empty or truncated content.
Set `thinking: true` to keep the model default.

### Request rules

Every field is required.
JaExC rejects missing keys and unknown keys.
JaExC does not convert types. For example, JaExC rejects `"N5"` and accepts `:N5`.

| Field | Rule |
|---|---|
| `exercise_type` | `:kanji_reading` or `:kanji_words`. |
| `target_kanji` | Nonempty unique Array of supported kanji. |
| `allowed_kanji` | Nonempty unique Array of supported kanji. It must contain every target kanji. |
| `level` | `:N5`, `:N4`, `:N3`, `:N2`, or `:N1`. |
| `count` | Integer from 1 to 10. |
| `translation_locales` | Nonempty unique Array of `:en` and `:pl`. |

The caller supplies `allowed_kanji` from its curriculum.
To get words from the target kanji only, give the same list as `target_kanji` and `allowed_kanji`.

### Result rules

A result contains exactly `count` exercises.
JaExC checks each exercise against the actual `jp` text, not against the model declarations:

- Every kanji in `jp` is in `allowed_kanji`. JaExC does not check kana, punctuation, or Latin characters.
- `jp` contains no whitespace, including the ideographic space U+3000.
- `jp` contains at least one target kanji.
- `target_kanji` lists each target kanji in `jp` exactly once.
- `reading` contains no kanji.
- `reading` contains only kana, the long vowel mark ー, and punctuation. It contains no whitespace, Latin letters, or digits.
- Two exercises do not have the same `jp` text.
- Each requested locale has a nonempty translation.

### Errors

Every error is a subclass of `JaExC::Error`.

| Error | Cause |
|---|---|
| `JaExC::InvalidRequestError` | The request breaks a request rule. JaExC does not call the provider. `#errors` lists every violation. |
| `JaExC::ProviderError` | The provider fails, times out, or is not available. |
| `JaExC::InvalidResponseError` | The model output is truncated at the token limit, is not valid JSON, or has the wrong structure. `#content` holds the raw output. |
| `JaExC::InvalidExerciseError` | An exercise breaks a result rule. `#exercises` holds the rejected exercises. |

JaExC makes one provider attempt for each `generate` call.
JaExC disables automatic retries. The caller decides if it retries.
JaExC never returns a partial result.

## CLI demo

The demo uses the same public interface.
It reads the provider settings from environment variables:

| Variable | Default |
|---|---|
| `JAEXC_LIVE_MODEL` | Required. |
| `JAEXC_BASE_URL` | `http://localhost:11434/v1` |
| `JAEXC_TIMEOUT` | `120` |

```bash
export JAEXC_LIVE_MODEL=<model>
bin/jaexc-demo --type kanji_reading --target 学 --allowed 学,校,日,本 \
  --level N5 --count 3 --locales en,pl
```

If generation fails, the demo prints the error class and message and exits with status 1.

## Model

| Item | Value |
|---|---|
| Model | `gemma4:26b-a4b-it-qat` (Gemma 4 26B-A4B, QAT Q4_0, 15.6 GB) |
| Digest | `2dd70431afed94dd3688d790443768c1487ed086b57147ff083851116ae4c4e4` |
| License | Apache 2.0 |

The live demo ran on 2026-10-17 with Ollama 0.40.5 on a GPU with 16 GB VRAM.

## Limitations

- Structural validation does not prove natural Japanese, correct readings, or correct translations.
- JaExC does not restrict politeness or speech style. Only `allowed_kanji` restricts content.
- JaExC does not prove JLPT level accuracy. The level only guides the model.
- JaExC supports only CJK Unified Ideographs (U+4E00 to U+9FFF).
  This range contains every jōyō kanji.
- JaExC rejects CJK Extension A and later extensions in requests and in `jp`.
- JaExC rejects CJK compatibility ideographs, because NFC normalization changes them to other code points.
- JaExC rejects Kangxi radicals, 〆, and 〇 in `jp`. JaExC permits the iteration mark 々 in `jp`.
- JaExC compares `jp` texts without Unicode normalization.
- JaExC supports only the `:en` and `:pl` translation locales.
- Local inference uses your hardware and electricity. It is not free to operate.
- JaExC does not log prompts or model output.

## Development

```bash
bin/setup
bundle exec rake          # Unit tests and RuboCop.
bundle exec rake mutant   # Mutation tests for request and domain validation.
```

The default tests use a fake provider. They do not need a model or network access.

To run the opt-in live test against a local Ollama model:

```bash
JAEXC_LIVE_MODEL=<model> bundle exec ruby -Ilib -Itest test/live/test_live_generation.rb
```

## License

JaExC is available under the [MIT License](LICENSE).
