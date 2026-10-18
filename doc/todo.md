# TODO

## 1. Dictionary reading check (warning)

Status: done on 2026-10-18. Live run: Run 5 in `doc/blog-notes.md`.

### Goal

Compare the model `reading` with a dictionary reading of `jp`.
If the two readings differ, add a warning to the exercise.
Do not reject the exercise for a reading difference.

### Evidence

Gemma 4 26B-A4B returned these wrong readings in live runs (see `doc/blog-notes.md`):

| jp | Model reading | Correct reading |
|---|---|---|
| 人は何を飲む | ひとはなにおをのむ | ひとはなにをのむ |
| 茶を飲みます | おちゃをのみます | ちゃをのみます |
| 友と食べます | ともだちとたべます | ともとたべます |
| 毎日食べます | まいにちはたべます | まいにちたべます |

The structural rules accepted all four exercises.
Use these four exercises as test fixtures.

### Why a warning and not a rejection

Some kanji have more than one correct reading.
Examples: 人 (ひと, じん, にん) and 今日 (きょう, こんにち).
An analyzer selects one reading from context.
If the analyzer selects a different correct reading, a rejection removes a good exercise.
A warning keeps the exercise and tells the teacher to check the reading.

### Owner decisions (2026-10-18)

| Question | Decision |
|---|---|
| Analyzer and dictionary | Sudachi CLI (`sudachi.rs` v0.7.0) with SudachiDict core. |
| Required or optional | Optional. Without an analyzer, `Creator` behaves as today. |
| Analyzer missing or broken | Fail fast. The adapter constructor checks the binary and the dictionary and analyzes one test sentence. |
| Warning location | `Result#warnings`. `Exercise` keeps only generated content. |
| Warning format | `ReadingWarning = Data.define(:jp, :model_reading, :analyzer_reading)`. |
| Analyzer cannot read a word | `ReadingWarning` with `analyzer_reading: nil`. It means "not verified". |
| Configuration | `Analyzers::SudachiCli.new(dictionary:, command: "sudachi")`, passed as `Creator.new(provider:, analyzer:)`. |
| CLI demo | Opt-in flag `--check-readings`. Dictionary path from `JAEXC_SUDACHI_DICT`. |
| Local tools | mise. `mise.toml` pins Sudachi. `mise run sudachi:dict` downloads the dictionary. |
| Error class | `JaExC::AnalyzerError < JaExC::Error` for a missing or broken analyzer. |

Reasons are in `doc/blog-notes.md`, "Choosing a dictionary for the reading check".
MeCab and IPAdic are frozen (2013 and 2007). Free web APIs send text off the machine.

### Design

- Analyzer port with one method: `reading(text) -> String or nil`.
  `nil` means the analyzer cannot read the text.
- Adapter `Analyzers::SudachiCli` runs the CLI through `Open3`.
  The name keeps room for a later adapter over a Ruby binding of `sudachi.rs`.
- Use a fake analyzer in default tests. Keep default tests deterministic.
- Keep a live Sudachi test opt-in, like the live Ollama test.
- Use column 5 of `sudachi -a` (reading form, katakana).
  It is the written reading: は gives ハ, を gives ヲ, へ gives ヘ. The model writes the same kana.
- Normalize both readings before the comparison:
  - Convert katakana to hiragana. Keep ー.
  - Remove punctuation.
- If the analyzer reading still contains a kanji after normalization, the analyzer did not know the word.
  Return `nil` for that text.
- One process can analyze many lines. The CLI writes `EOS` after each line.
- Keep the warning separate from generated content.
  `doc/mvp.md` says: "Keep generated content separate from verified validation metadata."

### Facts from the probe (2026-10-18)

- 何 always gives ナン in the core dictionary. A correct なにを also gets a warning.
- 一日 gives イチニチ. ついたち is also correct.
- 3人 gives サンニン. Digits get a reading.
- An unknown kanji gives the kanji itself as the reading (㷔 → 㷔).
- A missing dictionary makes the CLI panic with exit status 101.
- 3 process starts took 0.088 s in total.

### Done when

- The four fixture exercises get a warning.
- The correct exercises from `doc/blog-notes.md` get no warning, except for known analyzer limits such as 何.
- An unknown word gives a warning with `analyzer_reading: nil`.
- A missing binary or dictionary raises an error when the adapter is constructed.
- A live run with Gemma and Sudachi shows the warnings on real output.
- `README.md` and `doc/mvp.md` describe the warning and its limits.

## 2. Fine-tuning exercise (owner training)

Status: learning exercise for the owner. It is not part of the gem MVP.

### Goal

Fine-tune a small open-weight model for JaExC exercises.
Measure if the tuned model makes fewer errors than the base model.

### Proposed steps

1. Collect a dataset of correct exercises.
   Use only exercises that pass validation, pass the dictionary check, and have teacher approval.
   JaExC does not log output, so the caller must store the exercises.
2. Include the trap cases: words with a kanji that is not in `allowed_kanji`.
   Examples: 友だち, お茶.
3. Select a base model that fits 16 GB VRAM. Candidates: `gemma4:12b`, Gemma 4 E4B.
4. Train a LoRA adapter.
   Candidates: a local tool (for example Unsloth), or a hosted training API (for example Tinker).
5. Export the tuned model to GGUF and load it in Ollama.
6. Evaluate the base model and the tuned model on the same fixed set of requests.

### Metrics

- Rate of results that pass structural validation.
- Rate of exercises with no dictionary warning.
- Rate of invalid JSON responses.
- Time per request.
- Teacher score on a sample. Keep this score separate from the structural metrics.

### Open questions for the owner

1. How many exercises does the dataset need, and who approves them?
2. Local training or hosted training?
3. Which base model?

## 3. Empty model response (investigation)

Status: investigated on 2026-10-18. Cause: thinking fills the context. See `doc/blog-notes.md`, "Empty response investigation".

### Problem

Gemma 4 26B-A4B failed with `InvalidResponseError: invalid response: content is not valid JSON` in 2 of 5 live runs.
The runs used the 10-sentence request after the prompt changes.
In one failed run, the raw content had 0 characters.
In the other failed run, the raw content was not captured.
See `doc/blog-notes.md`, "Run 3 again".

### Hypotheses

Test each hypothesis. Do not change code before the cause is known.

1. Thinking mode: the model puts its output in a reasoning field, and the `content` field stays empty.
2. Output limit: the model reaches a token limit before it writes the JSON.
3. Structured output: the Ollama OpenAI-compatible endpoint does not apply the schema in the same way as the native API.
4. Context: the prompt and the output do not fit the loaded context (16384 tokens).

### Steps

1. Send the JaExC prompt and schema directly to Ollama with `curl`. Save the full raw response.
2. Repeat step 1 at least 5 times. Record the number of empty responses.
3. Do steps 1 and 2 for the OpenAI-compatible endpoint (`/v1/chat/completions`) and the native endpoint (`/api/chat`).
4. In each empty response, check `finish_reason` or `done_reason`, the token counts, and any reasoning field.
5. If a reasoning field holds the output, test the request with thinking disabled.

### Decision for the owner after the investigation

- If a provider setting is the cause, should the RubyLLM adapter set it?
- Should `InvalidResponseError` tell an empty response apart from broken JSON?

### Done when

- The cause is known and recorded in `doc/blog-notes.md`.
- The owner decides the fix.

## 4. Prompt tuning

Status: in progress. Accepted: candidate 2 (Run 6), candidate 5 (Run 7). Rejected: candidate 1 (Run 8). Evidence: Runs 4 to 8 in `doc/blog-notes.md`.

### Goal

Reduce rejected results and weak sentences without new validation rules.
Change one prompt line at a time. Measure each change with live runs.

### Problems

| Problem | Evidence |
|---|---|
| The model writes 友達 when 達 is not allowed. | 2 of 3 attempts in Run 4. Also in earlier runs. |
| Target kanji are not balanced. | 行 3, 飲 2, 食 2, 見 2, 来 1 in 10 sentences. |
| Some sentences are unnatural. | 水を見ます, 茶を見ます. |
| Some sentences repeat a pattern. | 何を食べますか twice, with a different time word. |
| Forbidden kanji are the main rejection cause. | 学校 4 times, 飯 3, 達 2, 明 1, 誰 1 in 12 attempts (Runs 5 and 6). |
| Target declarations are wrong. | 4 of 12 attempts (Runs 5 and 6). |

### Candidate prompt changes

Verify each candidate with live runs before the owner accepts it.

1. Remove 友だち from the kana fallback example. It possibly makes the model think of 友達.
   Measured in Run 8: pass rate 1 of 6 (Run 7: 3 of 6). 達 stayed (2 of 6 attempts), 飯 rose to 3 of 6. Rejected and reverted on 2026-10-18.
2. Done in Run 6: "Use the target kanji evenly: each target kanji should appear in about the same number of sentences."
   Result: target use 2 2 2 2 2 in both passes. Pass rate 2 of 6 (old prompt: 1 of 6).
5. Measured in Run 7: "Before you answer, check every kanji in each sentence against the allowed list."
   Result: pass rate 3 of 6. Forbidden kanji did not go down; 達 is the most frequent. Accepted on 2026-10-18.
3. Add a line: "Write natural sentences that a teacher would use in class."
4. Add a line: "Use a different sentence pattern in each sentence."

### Method

- Use the same fixed request for each measurement. Use the Run 4 request (Run 5 adds `--check-readings`).
- Do 6 attempts for each prompt version (owner decision, 2026-10-18).
- Record the pass rate, the rejection reasons, and the time per call.
- Keep linguistic judgment separate from the pass rate.
- Add a prompt builder test for each accepted line.

### Owner decisions (2026-10-18)

- Balanced use of targets is a prompt request only. No validation rule.
- 6 live attempts are enough to accept a prompt change.

### Done when

- Each accepted change has a test and a recorded live measurement.
- `doc/blog-notes.md` records the pass rate before and after.
