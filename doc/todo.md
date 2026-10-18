# TODO

## 1. Dictionary reading check (warning)

Status: agreed idea. Design and implementation start on 2026-10-18.

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

### Proposed design

- Add an analyzer port with one method. Example: `reading(text) -> String`.
- Add an analyzer adapter over a real morphological analyzer.
- Use a fake analyzer in default tests. Keep default tests deterministic.
- Normalize both readings before the comparison:
  - Convert katakana to hiragana.
  - Remove punctuation.
- Use the written reading field of the analyzer, not the pronunciation field.
  The particle は has the written reading は and the pronunciation わ.
  The model writes は, so the written reading matches.
- Keep the warning separate from generated content.
  `doc/mvp.md` says: "Keep generated content separate from verified validation metadata."

### Analyzer candidates

Verify each candidate before the decision.

| Candidate | Notes to verify |
|---|---|
| MeCab + `natto` gem | `natto` is a Ruby FFI binding. It needs the MeCab library and a dictionary (IPAdic or UniDic). |
| Sudachi | Check for a maintained Ruby binding. If no binding exists, check the CLI as a subprocess. |

The analyzer is a new runtime dependency. The owner must approve it.

### Open design questions for the owner

1. Which analyzer and which dictionary?
2. Where does the warning go: on `Exercise`, or in a separate validation object on `Result`?
3. What is the warning format: a Symbol, a String message, or an object with both readings?
4. Is the analyzer required, or optional? If optional, what happens when the analyzer is not installed?
5. Does the CLI demo print the warnings?

### Done when

- The four fixture exercises get a warning.
- The correct exercises from `doc/blog-notes.md` get no warning.
- A live run with Gemma shows the warnings on real output.
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

Status: open. Evidence from Run 4 in `doc/blog-notes.md`.

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

### Candidate prompt changes

Verify each candidate with live runs before the owner accepts it.

1. Remove 友だち from the kana fallback example. It possibly makes the model think of 友達.
2. Add a line: "Use each target kanji in at least one sentence."
3. Add a line: "Write natural sentences that a teacher would use in class."
4. Add a line: "Use a different sentence pattern in each sentence."

### Method

- Use the same fixed request for each measurement. Use the Run 4 request.
- Do at least 5 attempts for each prompt version.
- Record the pass rate, the rejection reasons, and the time per call.
- Keep linguistic judgment separate from the pass rate.
- Add a prompt builder test for each accepted line.

### Open questions for the owner

1. Is a balanced use of targets a prompt request only, or also a validation rule?
2. How many attempts are enough to accept a prompt change?

### Done when

- Each accepted change has a test and a recorded live measurement.
- `doc/blog-notes.md` records the pass rate before and after.
