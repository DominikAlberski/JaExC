# JaExC — Japanese Exercise Creator

## Goal

Build a reusable Ruby library that creates Japanese exercises with an open-weight model.

Japanese teachers are the first intended users through a consuming application.
The library should reduce preparation work without replacing teacher review.
Willingness to pay is unverified.

JaExC runs inside a monolith through Ruby method calls.
JTH is a future consumer, not an MVP dependency.

## Implementation as a learning exercise

The owner focuses on architecture, component boundaries, and orchestration.
The owner makes the design and interface decisions.
The assisting agent implements each agreed component with TDD and runs the checks.
Follow `AGENTS.md` for the working loop.

Work on one small, verifiable step at a time.
Implement a component only after the owner decides its open design questions.
Show real test and lint output before advancing.

## What to build

```text
CLI demo / future Rails application
                 |
           Ruby public API
                 |
       Request validation
                 |
        Prompt construction
                 |
       Model provider adapter
                 |
        Response validation
                 |
      Structured Ruby result
```

The MVP generates two kanji-reading exercise types:

- `:kanji_reading` generates sentences.
- `:kanji_words` generates dictionary words.

Each exercise contains Japanese text, its reading, translations, and target kanji.
The Japanese text is the canonical source.
Translations are supplementary model-generated content.

The caller supplies target kanji and the complete allowed-kanji set.
Generated text must use only allowed kanji.
Generated text can also contain hiragana and katakana.
Each exercise must contain at least one requested target kanji.
For "words from these kanji only", pass the same list as target and allowed kanji.

JLPT level guides generation.
JaExC must not claim that structural checks prove JLPT accuracy or natural Japanese.

## Architecture

**Decision:** Package JaExC as an independent Ruby gem with an in-process public API.

- Do not depend on Rails, Active Record, or an application database.
- Do not require HTTP between a consuming application and JaExC.
- Keep model communication separate from task-specific prompts and validation.
- Return structured objects, not provider-specific payloads.
- Accept provider configuration from the caller.
- Do not use global mutable configuration.

**Decision:** Use `ruby_llm` for model operations through one thin JaExC adapter.
Do not implement custom Ollama transport or another provider framework.
RubyLLM handles provider protocols, structured-output requests, and connection settings.
JaExC owns prompts, domain validation, result objects, and stable public errors.

Use an isolated `RubyLLM.context` for each configured adapter.
Do not mutate the consuming application's global RubyLLM configuration.
Set the provider, endpoint, timeout, retry policy, and logging policy explicitly.
Disable model thinking by default. Thinking can fill the context before the model writes the JSON.
The caller can enable thinking with `thinking: true`.
Create a fresh chat for each generation request.
Never share conversation history between requests.

The initial backend is local Ollama through RubyLLM.
An open-weight model must perform real generation in the demo.
Select the model after comparing Japanese output on representative inputs.
Record its exact name, version or digest, and license.

Model communication may use HTTP to a local Ollama process.
This does not make JaExC a separately deployed application service.

## Public interface

The following interface is a proposed contract, not an existing implementation.
The coding agent may refine names without changing the boundary or behaviour.

```ruby
provider = JaExC::Providers::RubyLLM.new(
  provider: :ollama,
  model: "<selected-open-weight-model>",
  base_url: "http://localhost:11434/v1",
  timeout: 60,
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
```

`allowed_kanji` includes learned kanji and any new target kanji permitted for this exercise.
The caller constructs this set from its curriculum.
JaExC does not infer lesson order or retrieve textbook content.

### Request contract

Every field is required.
Reject missing and unknown keys.
Use the documented types without coercion. For example, reject `"N5"` and accept `:N5`.
Collect every violation and raise one invalid-request error that lists all of them.

| Field | MVP rule |
|---|---|
| `exercise_type` | Symbol. One of `:kanji_reading`, `:kanji_words`. |
| `target_kanji` | Nonempty unique list of supported single-character kanji. |
| `allowed_kanji` | Nonempty unique list containing every target kanji. |
| `level` | Symbol. One of `:N5`, `:N4`, `:N3`, `:N2`, `:N1`. |
| `count` | Integer from 1 to 10. |
| `translation_locales` | Nonempty unique subset of the symbols `:en` and `:pl`. |

Reject invalid requests before contacting the provider.
Define the supported kanji ranges explicitly.
Reject unsupported character forms rather than silently bypassing validation.
Do not treat hiragana, katakana, punctuation, or Latin characters as kanji.
Document Unicode limitations and test range boundaries.

### Result contract

Return a result containing exactly the requested exercise count.
Each exercise exposes these fields:

| Field | Description |
|---|---|
| `jp` | Nonempty Japanese sentence or word, by exercise type. |
| `reading` | Nonempty kana reading for `jp`. |
| `translations` | Nonempty text for each requested locale, keyed by locale. |
| `target_kanji` | Requested target kanji actually present in `jp`. |

Validate the response structure before constructing result objects.
Use RubyLLM's structured-output support with an explicit exercise schema.
Verify support against the selected Ollama model in a real inference run.
Keep application-side validation even when the provider accepts the schema.
Schema compliance does not prove correct readings, translations, or allowed-kanji compliance.
Validate kanji against the actual `jp` text, not the model's declared list.
Reject a result that contains the same `jp` text in two exercises.
Require at least one requested target kanji per exercise.
Reject undeclared or incorrectly declared targets and forbidden kanji.
Detect kanji in `jp` with the Unicode `Han` and `Ideographic` properties.
Reject a detected character outside the supported kanji range, except the iteration mark 々.
Reject every `Han` or `Ideographic` character in `reading`, including 々.
Reject whitespace in `jp`, including the ideographic space U+3000.
Accept only kana, the long vowel mark ー, and punctuation in `reading`. Reject whitespace, Latin letters, and digits.
Do not restrict politeness or speech style. Only the allowed-kanji list restricts content.
Do not pad missing exercises with fabricated content.

Include the provider and model identifiers in result metadata.
Keep generated content separate from verified validation metadata.
A valid result means structural and character constraints passed.
It does not mean the language or translations are teacher-approved.

### Failure contract

Expose stable library errors for these failure categories:

- Invalid request.
- Provider connection failure or timeout.
- Invalid response JSON or structure, including output truncated at the token limit.
- Exercise constraint violation.
- Reading analyzer missing or broken. This applies only when the caller passes `analyzer:`.

Do not expose provider exceptions as the public contract.
Do not return partial exercises as a successful result.
The MVP performs one provider attempt per generation request.
Set RubyLLM's `max_retries` to `0` to disable automatic transport retries.
The adapter sets `max_retries` to `0`. The caller cannot change this value.
The caller decides whether to retry.

### Reading check contract

Status: implemented on 2026-10-18. Live run with Gemma and Sudachi: Run 5 in `doc/blog-notes.md`.

The reading check is optional.
It compares the model `reading` with the reading from a morphological analyzer.
A difference gives a warning. It does not reject the exercise.
An analyzer selects one reading from context, and other readings can also be correct.

```ruby
analyzer = JaExC::Analyzers::SudachiCli.new(
  dictionary: "~/.local/share/sudachi/system_core.dic",
  command: "sudachi"
)

creator = JaExC::Creator.new(provider: provider, analyzer: analyzer)
result = creator.generate(**request)
result.warnings # => [JaExC::ReadingWarning, ...]
```

- Without `analyzer:`, `Creator` does not check readings, and `Result#warnings` is empty.
- The analyzer port has one method: `reading(text)`. It returns kana, or `nil` if the analyzer cannot read the text.
- The first adapter runs the Sudachi CLI (`sudachi.rs`) with the SudachiDict core dictionary.
- The adapter constructor checks the binary and the dictionary and analyzes one test sentence.
  If the check fails, it raises `JaExC::AnalyzerError`. A caller that asks for the check does not get a silent skip.
- `ReadingWarning` has the fields `jp`, `model_reading`, and `analyzer_reading`.
  `analyzer_reading` is `nil` if the analyzer cannot read a word in `jp`.
- Warnings are validation metadata on `Result`. `Exercise` keeps only generated content.
- Before the comparison, convert katakana to hiragana and remove punctuation in both readings.
- A warning does not prove an error. The analyzer can be wrong. Example: Sudachi reads 何を as なんを.
- Default tests use a fake analyzer. A live Sudachi test is opt-in.
- The CLI demo checks readings only with `--check-readings`. It reads the dictionary path from `JAEXC_SUDACHI_DICT`.

## Components

| Component | Responsibility |
|---|---|
| Public creator | Coordinate generation through the public interface. |
| Request object | Validate and represent caller input. |
| Prompt builder | Describe the exercise and output schema. |
| RubyLLM adapter | Use isolated configuration and return generated output with model metadata. |
| Response parser | Parse and validate the output shape. |
| Domain validator | Enforce target and allowed-kanji constraints. |
| Result objects | Expose validated exercises and metadata. |
| Reading analyzer (optional) | Give a second reading of `jp`. Readings that differ become warnings. |
| CLI demo | Exercise the same public API without Rails. |

Keep persistence, rendering, and business ownership outside these components.
Avoid building a generic workflow framework for one exercise task.

## Repository layout

```text
JaExC/
  doc/
    mvp.md
  README.md                 # Setup, public API, limitations, demo instructions.
  LICENSE                   # MIT, selected by the owner.
  Gemfile
  jaexc.gemspec
  lib/
    jaexc.rb
    jaexc/
  test/
  bin/
    jaexc-demo
```

Only this specification exists at project initialization.
The layout describes implementation deliverables, not current files.

## Scope — MVP

Each criterion is Pass or fail.

1. Package the library as a gem that loads without Rails. Pass or fail.
2. Generate exercises through the public Ruby interface. Pass or fail.
3. Validate invalid requests before provider calls. Pass or fail.
4. Generate real exercises with an open-weight model through Ollama. Pass or fail.
5. Return exactly the requested exercise count and requested translations. Pass or fail.
6. Reject generated text containing kanji outside the allowed set. Pass or fail.
7. Require and verify requested target kanji in each exercise. Pass or fail.
8. Return stable errors for provider and output failures. Pass or fail.
9. Run a CLI demo through the same public API. Pass or fail.
10. Document setup, model license, limitations, and the public interface. Pass or fail.
11. Pass unit and public-interface integration tests. Pass or fail.
12. Pass mutation testing for request and domain-validation rules. Pass or fail.
13. Obtain teacher review of a real generated sample before claiming teaching quality. Pass or fail.
14. Use RubyLLM without modifying global configuration or sharing request history. Pass or fail.
15. Verify structured output with the selected local model and disable automatic retries. Pass or fail.

Track each criterion as Green or Red when evidence exists.
Do not mark planned work Green.
Record the tested model identifier and real sample output for the live demo.

## Testing

Use TDD for implementation.
Use a fake provider for deterministic tests.
Test prompt construction without contacting a model.
Test the public interface with success and failure responses.

Cover truncated output, malformed JSON, missing fields, empty translations, and incorrect exercise counts.
Cover forbidden kanji, missing targets, false target declarations, duplicates, whitespace, reading characters, and Unicode boundaries.
Cover timeouts and connection failures.
Prove invalid input makes no provider call.
Test the thin RubyLLM adapter separately from domain logic.
Prove adapter configuration does not change global RubyLLM settings.
Prove successive generation calls use separate chats.
Prove transport retries are disabled.

Keep live model tests opt-in.
Never require model downloads or network access for the default test suite.
A real local inference run remains mandatory for MVP demonstration.

## Deferred — plan only

- Rails integration and JTH persistence.
- HTTP server, remote service deployment, and Rails engine.
- Accounts, billing, and administration.
- PDF generation, worksheet layout, and editing screens.
- Curriculum databases, dictionary ingestion, and textbook imports.
- Exercise types other than `:kanji_reading` and `:kanji_words`, and additional translation locales.
- Additional backends beyond Ollama through the RubyLLM adapter.
- Automatic retries, corrective generation, and streaming.
- Fine-tuning, retrieval, agent tools, and workflow orchestration.
- Automatic linguistic certification or guaranteed JLPT classification.

## Pitfalls

- **P1:** Validate actual output because model declarations can be false.
- **P2:** Keep teacher review explicit because structural validation cannot prove linguistic quality.
- **P3:** Keep curriculum ownership with the caller because applications organize lessons differently.
- **P4:** Keep credentials and provider configuration outside generated prompts because they are not exercise content.
- **P5:** Do not log prompts or responses by default because caller content may be private.
- **P6:** Do not silently use cloud fallback because it contradicts the local-inference privacy claim.
- **P7:** Do not promise free operation because local inference still consumes hardware and electricity.
- **P8:** Do not copy old code without checking licensing because the original repository contains GPLv3.

## Why open innovation matters

Local inference can keep generation requests on hardware controlled by the user.
Provider isolation allows model replacement without changing consuming applications.
Open source lets teachers and developers inspect the prompt and validation rules.
Measure output quality and generation time before claiming an advantage over closed services.

## Challenge submission

The Week 2 theme is Side Hustle.
Explain the intended buyer and the preparation work JaExC could reduce.
Do not claim payment or demand without user evidence.

The official entry period is October 12–18, 2026, ending at 11:59 PM PDT.
The challenge requires a brand-new project built during that period.
Present JaExC as the new standalone library.
Disclose the older projects as prior inspiration and future consumers.
Do not describe pre-existing JTH work as challenge-period implementation.

Publish a DEV submission using the required template and tags.
Include a code repository link and a deployed demo or video demonstration.
Explain which open model powers the project and why that choice matters.
Writing quality has the highest judging weight.

Select a source license before public release.
The owner selected the MIT License.
Record real generation failures for the write-up instead of inventing examples.

Sources:

- https://dev.to/challenges/hacktoberfest-week2-2026-10-12
- https://dev.to/page/hacktoberfest-week2-2026-10-12-contest-rules
- https://rubyllm.com/configuration-providers/
- https://rubyllm.com/structured-output/
- https://rubyllm.com/configuration-connection/
