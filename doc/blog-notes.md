# Blog notes — live runs and findings

Raw material for the DEV post (Hacktoberfest Week 2, "Side Hustle", `#hf26challenge`, Gemma category).
Deadline: 2026-10-18 11:59 PM PDT (2026-10-19 08:59 CEST).
All output below is real command output from 2026-10-17. No output is edited.

## Setup

| Item | Value |
|---|---|
| Ollama | 0.40.5, on a LAN machine with 16 GB VRAM |
| Client | `bin/jaexc-demo`, `JAEXC_BASE_URL=http://<lan-host>:11434/v1` |
| Model A | `qwen3.8-ridge-16k:latest`, 27.3B dense, community fine-tune, license unknown |
| Model A digest | `2e55e199b770fd3e01424522b9e6ea4b2f8e255b16e6dca47a1492f1cbe5d087` |
| Model B | `gemma4:26b-a4b-it-qat`, 26B MoE (4B active), QAT Q4_0, 15.6 GB, Apache 2.0 |
| Model B digest | `2dd70431afed94dd3688d790443768c1487ed086b57147ff083851116ae4c4e4` |

Gemma memory split during the runs (from `/api/ps`): 15.9 GB total, 13.1 GB in VRAM, context 16384.

## Why Gemma 4 (research)

- Swallow LLM Leaderboard, Japanese average: Gemma 4 31B IT 0.675, Gemma 4 26B-A4B IT 0.646,
  Qwen3.5-27B 0.621, Qwen3-14B 0.524. <https://swallow-llm.github.io/leaderboard/index-post.ja.html>
- Gemma 4 is Apache 2.0. <https://opensource.googleblog.com/2026/03/gemma-4-expanding-the-gemmaverse-with-apache-20.html>
- 31B dense Q4 (19-20 GB) does not fit 16 GB VRAM. 26B MoE QAT (16 GB) nearly fits; only 4B parameters are active per token.
- JaExC needs a small context: about 300 prompt tokens plus output. Large context variants waste VRAM.

## Timings

| Run | Qwen 27B | Gemma 26B-A4B |
|---|---|---|
| kanji_reading, 3 sentences | 3:21 | 1:26 (includes cold load) |
| kanji_words, 4 words | 0:48 | 0:59 |
| kanji_reading, 10 sentences | not run | 1:32 |
| kanji_reading, 10 sentences, thinking off | not run | 0:07 to 0:14 |

## Run 1 — kanji_reading, target 学

```bash
bin/jaexc-demo --type kanji_reading --target 学 --allowed 学,校,日,本,生,先,行,私 \
  --level N5 --count 3 --locales en,pl
```

Qwen:

```
1. 私は学生です。       わたしはがくせいです。         I am a student. / Jestem studentem.
2. 私は学校にいく。     わたしはがっこうにいく。       I go to school. / Idę do szkoły.
3. 私は日本の学生です。 わたしはにほんのがくせいです。 I am a Japanese student. / Jestem japońskim studentem.
```

Gemma:

```
1. 私は学生です。       わたしはがくせいです。       I am a student. / Jestem studentem.
2. 先生は学校に行きます。 せんせいはがっこうにいきます。 The teacher goes to school. / Nauczyciel idzie do szkoły.
3. 日本の学校です。     にほんのがっこうです。       It is a Japanese school. / To jest japońska szkoła.
```

Notes: Qwen wrote いく in kana although 行 was allowed. Gemma used 行きます.

## Run 2 — kanji_words, targets 日 本

```bash
bin/jaexc-demo --type kanji_words --target 日,本 --allowed 日,本,人,語,学,校,生,月,曜 \
  --level N5 --count 4 --locales en,pl
```

Qwen:

```
1. 日本       にほん           Japan / Japonia
2. 日本語     にほんご         Japanese / język japoński
3. 日本人     にほんじん       Japanese person / osoba japońska
4. 日本語学校 にほんごがっこう Japanese language school / szkoła języka japońskiego
```

Gemma:

```
1. 日本   にほん     Japan / Japonia
2. 本     ほん       book / książka
3. 日本語 にほんご   Japanese language / język japoński
4. 日曜日 にちようび Sunday / niedziela
```

Notes: Qwen put both targets in every word. Gemma gave more variety (本 alone, 日曜日).
Qwen's "osoba japońska" is unnatural Polish; "Japończyk" is natural.

## Run 3 — Gemma, 10 sentences, targets 食 飲

```bash
bin/jaexc-demo --type kanji_reading --target 食,飲 \
  --allowed 食,飲,水,私,毎,日,朝,何,茶,友,人,店,行,今 --level N5 --count 10 --locales en,pl
```

```
1.  私 は 水 を 飲 む。       わたしはみずをのむ。       I drink water. / Piję wodę.
2.  友 と 食 べ る。          ともとたべる。             Eat with a friend. / Jeść z przyjacielem.
3.  今 は 茶 を 飲 む。       いまはちゃをのむ。         Drink tea now. / Piję herbatę teraz.
4.  何 を 食 べ る?          なにをたべる。             What to eat? / Co jeść?
5.  店 で 食 べ る。          みせでたべる。             Eat at the shop. / Jeść w sklepie.
6.  朝 は 水 を 飲 む。       あさはみずをのむ。         Drink water in the morning. / Pić wodę rano.
7.  人 は 何 を 食 べ る?    ひとはなにをたべる。       What does a person eat? / Co je człowiek?
8.  友 は 茶 を 飲 む。       ともはちゃをのむ。         A friend drinks tea. / Przyjaciel pije herbatę.
9.  今 は 食 べ る。          いまはたべる。             Eat now. / Jeść teraz.
10. 人 は 何 を 飲 む?       ひとはなにおをのむ。       What does a person drink? / Co pije człowiek?
```

The validator accepted this result. Findings:

1. Every `jp` has a space between characters. A teacher cannot use any of the 10 sentences.
2. Run 10 has a wrong reading: なにおをのむ. Correct: なにをのむ. Structural validation cannot detect this.
3. `jp` ends with `?`, but `reading` ends with `。`.
4. Polish translations use infinitives ("Jeść z przyjacielem") and the grammatical person changes.
5. The sentences are very simple. A narrow allowed-kanji list possibly causes this.

## Fix that came from Run 3

New result rule: `jp` must not contain whitespace (`\p{Space}`, includes ASCII space and U+3000).
The validator now raises `InvalidExerciseError` with `exercises[i].jp must not contain whitespace`.
Test first (RED: "InvalidExerciseError expected but nothing was raised"), then implementation.
After the change: 107 runs, 0 failures; RuboCop clean; mutant 846/846 kills, 100% coverage.

Owner decision: JaExC does not restrict politeness or speech style.
The only content restriction is the allowed-kanji list. Any natural form of a sentence is acceptable.

Blog angle: the model reports its own target kanji, but JaExC checks the actual `jp` text.
A live run produced output that every declared field accepted, and the actual text was still unusable.
That is why the rules check the text, and why a teacher review is still necessary for readings and translations.

## Run 3 rerun — after the whitespace rule

Same command, same model, 2:09. Gemma again spaced every sentence. JaExC rejected the result, exit status 1:

```
JaExC::InvalidExerciseError: invalid exercises: exercises[0].jp must not contain whitespace; exercises[1].jp must not contain whitespace; exercises[2].jp must not contain whitespace; exercises[3].jp must not contain whitespace; exercises[4].jp must not contain whitespace; exercises[5].jp must not contain whitespace; exercises[6].jp must not contain whitespace; exercises[7].jp must not contain whitespace; exercises[8].jp must not contain whitespace; exercises[9].jp must not contain whitespace
```

The spacing repeated for this request, so it is not a one-off. The validator stops it.

## Run 3 again — after the prompt change

Owner decision: add "Do not put spaces in the Japanese text." to both prompt templates.
The validator rule stays as the safety net.

Attempt 1 (2:31) failed with a new error. The raw output was not captured, because the demo prints only the message:

```
JaExC::InvalidResponseError: invalid response: content is not valid JSON
```

Attempt 2 (2:20, through `Creator` in a Ruby script) passed validation:

```
私は食べます     わたしはたべます     I eat. / Jem.
水を飲みます     みずをのみます       I drink water. / Piję wodę.
朝は食べます     あさはたべます       I eat in the morning. / Jem rano.
茶を飲みます     おちゃをのみます     I drink tea. / Piję herbatę.
友と食べます     ともだちとたべます   I eat with a friend. / Jem z przyjacielem.
店で食べます     みせでたべます       I eat at the shop. / Jem w sklepie.
何を飲みますか   なにをのみますか     What will you drink? / Co będziesz pić?
人が食べます     ひとがたべます       A person eats. / Człowiek je.
今は飲みます     いまはのみます       I drink now. / Teraz piję.
毎日は食べます   まいにちはたべます   I eat every day. / Jem codziennie.
```

Improvements: no spaces, consistent です/ます, natural Polish in the first person.
New problems: the readings add kana that is not in `jp`, and one particle is unnatural (see the table below).
One attempt per `generate` call is the design. The caller decides about retries, so attempt 2 was a caller retry.

## Run 3 again — after the kana fallback line

Owner decision: add two lines to both prompt templates:

```
If a word needs a kanji that is not allowed, write that part in kana, for example お茶 or 友だち.
The reading must match the Japanese text exactly.
```

Three attempts with the same request:

Attempt 1 (0:20) was rejected by the validator:

```
invalid exercises: exercises[3].jp contains forbidden kanji: 達; exercises[3].jp contains no target kanji; exercises[3].target_kanji must list each target kanji in jp exactly once; exercises[6].jp contains forbidden kanji: 一, 緒, 事; exercises[9].jp contains forbidden kanji: 飯
```

The model wrote 友達, 一緒, 食事, and ご飯. The example 友だち possibly made the model think of 友達.

Attempt 2 failed with `InvalidResponseError: invalid response: content is not valid JSON`.
The raw content had 0 characters. The model returned empty content, not broken JSON.
The cause is not known yet.

Attempt 3 passed validation:

```
私は水を飲みます。     わたしはみずをのみます。       I drink water. / Piję wodę.
今は店で食べます。     いまはみせでたべます。         I eat at the shop now. / Teraz jem w sklepie.
毎日は茶を飲みます。   まいにちはちゃをのみます。     Every day I drink tea. / Każdego dnia piję herbatę.
何を食べますか。       なにをたべますか。             What do you eat? / Co jesz?
友だちは茶を飲みます。 ともだちはちゃをのみます。     My friend drinks tea. / Mój przyjaciel pije herbatę.
朝は水を飲みます。     あさはみずをのみます。         I drink water in the morning. / Rano piję wodę.
人は食べます。         ひとはたべます。               People eat. / Ludzie jedzą.
何を飲みますか。       なにをのみますか。             What do you drink? / Co pijesz?
毎日食べます。         まいにちはたべます。           I eat every day. / Jem codziennie.
今は何を食べますか。   いまはなにをたべますか。       What are you eating now? / Co teraz jesz?
```

Improvements: 友だち with ともだち, 茶 with ちゃ, sentence-final 。 in jp and reading, natural Polish.
Remaining error: 毎日食べます has the reading まいにち**は**たべます. The reading adds は, which is not in jp.
The prompt line "The reading must match the Japanese text exactly." did not prevent this error.
The dictionary reading check (`doc/todo.md`) would detect this error.

## Empty response investigation (2026-10-18)

Problem: Gemma failed with `content is not valid JSON` in 2 of 5 live runs. One failure had 0 characters of content.

Method: we captured the exact request body that RubyLLM sends.
RubyLLM sends only `model`, `messages`, `stream: false`, and `response_format` (strict `json_schema`).
It sends no thinking setting, no `max_tokens`, and no `num_ctx`.
We sent the same 10-sentence request with `curl`, 5 times to each endpoint, and saved each raw response.
Ollama 0.40.6 lists `thinking` as a capability of `gemma4:26b-a4b-it-qat`.

Thinking on (Ollama default, which JaExC used):

| Endpoint | Empty content | Truncated JSON | Complete | Time per call |
|---|---|---|---|---|
| `/v1/chat/completions` | 4 | 1 | 0 | about 136 s |
| `/api/chat` | 3 | 0 | 2 | 120 to 136 s |

Each failure had the stop reason `length` and the same token count: 213 prompt + 16171 output = 16384.
16384 is the context that Ollama loads for the model.
The model wrote 31,000 to 39,000 characters of reasoning in a separate `reasoning` or `thinking` field.
The context became full before the model wrote the JSON.

Cause: thinking fills the context. Empty content and truncated JSON are the same failure.
The endpoint is not the cause, because both endpoints fail in the same way.

Prompt finding: the reasoning shows that Gemma read "Write every other word in kana" as
"alternate a kanji word and a kana word". The model used thousands of tokens on this pattern.
The intended meaning is "Write all other words in kana".

Thinking off (`reasoning_effort: "none"` on `/v1`, `think: false` on `/api/chat`):

- 10 of 10 responses had complete JSON with the stop reason `stop`.
- Time per call: about 7 s. Output: about 800 tokens.
- 5 of 10 results passed JaExC validation (native 4 of 5, OpenAI-compatible 1 of 5; the sample is small).
- Rejections: forbidden kanji in 友達, 食事, ご飯, and one duplicate sentence.

Errors in results that passed validation with thinking off:

- `友人は水を飲む` → `ゆうじんlyはみずをのむ`: Latin letters in the reading.
- `私は水を飲みます` → `わたしは みずを のみます`: spaces in the reading.
- `友だちと茶を飲みます` → `ともだちとおちゃをのみます`: the reading adds お.
- `人は水を食べません`: "People do not eat water". Meaning is not validated.

Thinking on passed validation in 2 of 2 complete responses, but it was 20 times slower and failed 7 of 10 calls.

Owner decisions:

1. The adapter disables thinking by default, with an option to enable it.
2. `InvalidResponseError` tells a truncated response apart from broken JSON.
3. The prompt line changes to "Write all other words in kana."
4. A new rule: the reading contains only kana, the long vowel mark, and punctuation. No whitespace.

## Run 4 — thinking off, 5 targets (2026-10-18)

First live run through JaExC after the four fixes from the empty response investigation.

```
--type kanji_reading --target 食,飲,行,見,来
--allowed 食,飲,行,見,来,水,私,毎,日,朝,何,茶,友,人,店,今,学,校
--level N5 --count 10 --locales en,pl
```

| Attempt | Time | Result |
|---|---|---|
| 1 | 0:14 | Rejected: `exercises[6].jp contains forbidden kanji: 達` |
| 2 | 0:07 | Rejected: `exercises[3].jp contains forbidden kanji: 達` |
| 3 | 0:07 | Passed validation |

Attempt 3:

```
私は毎日水を飲みます。   わたしはまいにちみずをのみます。   I drink water every day. / Piję wodę codziennie.
毎朝、茶を飲みます。     まいあさ、ちゃをのみます。         I drink tea every morning. / Piję herbatę każdego ranka.
今、学校へ行きます。     いま、がっこうへいきます。         I am going to school now. / Idę teraz do szkoły.
友だちと店へ行きます。   ともだちとみせへいきます。         I will go to the shop with my friend. / Idę do sklepu z przyjacielem.
毎日、何を食べますか。   まいにち、なにをたべますか。       What do you eat every day? / Co jesz codziennie?
今、水を見ます。         いま、みずをみます。               I look at the water now. / Teraz patrzę na wodę.
友だちが来ます。         ともだちがきます。                 A friend is coming. / Przychodzi przyjaciel.
朝、何を食べますか。     あさ、なにをたべますか。           What do you eat in the morning? / Co jesz rano?
毎日、学校へ行きます。   まいにち、がっこうへいきます。     I go to school every day. / Codziennie chodzę do szkoły.
今、茶を見ます。         いま、ちゃをみます。               I look at the tea now. / Teraz patrzę na herbatę.
```

Improvements:

- Time per call: 7 to 14 s. With thinking on, the same size of request took about 2:15.
- No empty or truncated output in 3 attempts.
- All readings in attempt 3 look correct on manual review (毎朝 まいあさ, 茶 ちゃ, 来ます きます).
  No dictionary check confirms this yet.

Problems:

- 友達 caused 2 of 3 rejections. 友 is allowed, 達 is not. The prompt example 友だち did not prevent it.
- Target use is not balanced: 行 3, 飲 2, 食 2, 見 2, 来 1. No sentence uses two targets.
- 水を見ます and 茶を見ます are grammatical but unnatural.
  The small allowed set forces 見 onto any available noun.
- 何を食べますか occurs twice with a different time word.

## Choosing a dictionary for the reading check (2026-10-18)

Structural rules cannot see a wrong reading such as おちゃ for 茶.
A morphological analyzer can give a second reading to compare.

Free web APIs checked first:

| Option | Fit | Status on 2026-10-18 |
|---|---|---|
| Yahoo! JAPAN Text Analysis (furigana V2) | Sentence in, reading out | Active (new features 2026-09). Needs an app ID. Text leaves the machine. V1 was shut down in 2022. |
| Jisho.org | Word lookup only; needs a tokenizer first | No official API. Wrappers: last release 2020. |
| Jotoba | Word lookup, sentence breakdown | Last push 2024-01. |
| kanjiapi.dev | Single kanji only | Cannot select 人 = ひと or にん from context. |

Local analyzers checked next:

| Option | Status on 2026-10-18 |
|---|---|
| MeCab 0.996 | Last release 2013. Still packaged, but frozen. |
| IPAdic (MeCab dictionary) | Frozen since 2007-08. No newer words. |
| `natto` gem (MeCab binding) | Last push 2020-03. |
| Sudachi (`sudachi.rs`) | v0.7.0 released 2026-09-24. Active. |
| SudachiDict | v20261015 released 2026-10-15. Updates every few months. |

Decision: Sudachi CLI, optional analyzer, fail fast if the caller asks for it and it is missing.
Reason: the only local option that is still maintained. JaExC stays local-first.
A Ruby gem around `sudachi.rs` can become a second adapter later.

Install notes:

- Sudachi is not on crates.io and not in Homebrew. The GitHub release has no binaries.
- mise installs it from the git tag. The repo has two binaries, so mise needs `crate=sudachi-cli`:
  `mise install 'cargo:https://github.com/WorksApplications/sudachi.rs[crate=sudachi-cli]@tag:v0.7.0'` (22.7 s build).
- The binary contains no dictionary ("bake dictionary" is not implemented upstream).
  The core dictionary `system_core.dic` is 192.9 MB. A deploy ships two artifacts.
- A missing dictionary makes the CLI panic with exit status 101.
- 3 process starts with the core dictionary took 0.088 s in total. One process can read many lines (one `EOS` per line).

Probe of the reading field (`-a`, column 5, katakana):

| Input | Sudachi reading | Note |
|---|---|---|
| 茶を飲みます | チャヲノミマス | Fixture: model wrote おちゃ, so a warning |
| 友と食べます | トモトタベマス | Fixture: model wrote ともだち, so a warning |
| 毎日食べます | マイニチタベマス | Fixture: model added は, so a warning |
| 人は何を飲む | ヒトハ**ナン**ヲノム | Analyzer is wrong too: correct is なにを |
| 何が好き | **ナン**ガスキ | 何 is always ナン in the core dictionary |
| 東京へ行きます | トウキョウヘイキマス | Written form: は→ハ, を→ヲ, へ→ヘ |
| 3人で行く | サンニンデイク | Digits get a reading |
| 一日 | イチニチ | ついたち is also correct |
| 「はい」と言った。 | 「ハイ」トイッタ。 | Punctuation stays; remove before comparison |
| 㷔を見る | 㷔ヲミル | Unknown kanji: the reading is the kanji itself |
| 茶 茶 | チャ**キゴウ**チャ | A space is a token with the reading キゴウ (記号, "symbol") |

Without `-a`, the CLI writes only 3 columns and no reading.

Mutant on the Sudachi adapter (first version: 18 alive mutations of 1187):

- The fake CLI ignored `-a`. Removing the flag passed every test. The fake now writes 3 columns without `-a`, like the real CLI.
- The `EOS` filter was dead code. `EOS` has no column 5, so it adds nothing to the reading.
- Splitting on any whitespace passed every test. The real space token (キゴウ) became the test for tab-only splitting.

Lesson: the analyzer is a second opinion, not the truth.
何 shows it: Sudachi says ナン where なに is correct, so a correct model reading also gets a warning.
This is the evidence for "warning, not rejection".

## Run 5 — reading check with Sudachi (2026-10-18)

Same request as Run 4, with `--check-readings`:
targets 食 飲 行 見 来, allowed 食 飲 行 見 来 茶 水 友 毎 日 人 何 今 朝, N5, 10 sentences, en and pl.
Gemma 4 26B-A4B QAT, thinking off. Sudachi 0.7.0 with SudachiDict core 20261015.
Recorded with asciinema 3.2.1 (`--headless`, 120x40). Files (local, git-ignored): `tmp/demo/jaexc-run5-1.cast` to `-6.cast`.

| Attempt | Time | Result |
|---|---|---|
| 1 | 16 s | Pass. 2 reading warnings. |
| 2 | 5 s | Rejected: 学, 校, 飯 |
| 3 | 7 s | Rejected: 明 |
| 4 | 8 s | Rejected: target declaration |
| 5 | 7 s | Rejected: target declaration, 達, 学, 校 |
| 6 | 7 s | Rejected: target declaration, 飯 |

Attempt 1 output (all 10 readings look correct on manual review):

| # | jp | reading |
|---|---|---|
| 1 | 毎朝水を飲みます。 | まいあさみずをのみます。 |
| 2 | 友だちを食べに来ます。 | ともだちをたべにきます。 |
| 3 | 今、お茶を見ます。 | いま、おちゃをみます。 |
| 4 | 何を食べますか。 | なにをたべますか。 |
| 5 | 毎日行きます。 | まいにちいきます。 |
| 6 | 人は水を飲みます。 | ひとはみずをのみます。 |
| 7 | 朝、茶を見ます。 | あさ、ちゃをみます。 |
| 8 | 今、来ますか。 | いま、きますか。 |
| 9 | 友だちは何を食べますか。 | ともだちはなにをたべますか。 |
| 10 | 毎日お茶を飲みます。 | まいにちおちゃをのみます。 |

Reading check output:

```text
reading check (Sudachi): 2 difference(s); a difference is not proof of an error
- 何を食べますか。: model なにをたべますか。, analyzer ナンヲタベマスカ。
- 友だちは何を食べますか。: model ともだちはなにをたべますか。, analyzer トモダチハナンヲタベマスカ。
```

Findings:

- Both warnings are false positives. The model is correct (なにを). Sudachi reads 何 as ナン.
- 8 of 8 other readings agree with Sudachi, including お茶 → おちゃ (お is in jp here).
- No real reading error in this run, so the run does not show a true positive.
  The true positives are the four fixtures from earlier runs (see the live Sudachi test).
- Pass rate 1 of 6 is lower than Run 4. Rejections: forbidden kanji (学校 3 times, 飯 2, 明, 達)
  and target declarations (3 attempts). The prompt tuning item covers this.
- Sentence 2 (友だちを食べに来ます) means "(someone) comes to eat the friend". The particle を makes the friend the food.
  The translation "A friend is coming to eat" hides the error. Correct: 友だちが食べに来ます.
  Sentences 3 and 7 (お茶を見ます) are unnatural again. Neither check can see this.

## Run 6 — prompt line for even target use (2026-10-18)

Owner decisions: balanced target use is a prompt request only, not a validation rule.
A prompt change is measured with 6 live attempts of the Run 5 request.

New line in both templates, after the "at least one target kanji" line:
"Use the target kanji evenly: each target kanji should appear in about the same number of sentences."
(`words` in the `kanji_words` template.)
"Each target kanji in at least one sentence" was rejected: it is impossible when count is smaller than the target count.

| Attempt | Time | Result |
|---|---|---|
| 1 | 15 s | Rejected: target declaration, 誰 |
| 2 | 7 s | Rejected: 学, 校 |
| 3 | 7 s | Rejected: 飯 (twice) |
| 4 | 5 s | Rejected: 達 (twice) |
| 5 | 6 s | Pass. 3 reading warnings. |
| 6 | 7 s | Pass. 1 reading warning. |

| Measure | Run 4 / Run 5 (old prompt) | Run 6 (new line) |
|---|---|---|
| Pass rate | 1 of 6 (Run 5) | 2 of 6 |
| Target use in a passing result (食 飲 行 見 来) | 2 2 3 2 1 (Run 4) | 2 2 2 2 2, both passes |

The pass rate difference is small for 6 attempts. The target balance is the clear effect.

First true positive of the reading check on live output (attempt 5):

```text
- 友が来ます。: model ともだちがきます。, analyzer トモガキマス。
```

The model read 友 alone as ともだち. Correct: ともがきます. Structural rules accept it.
The other 3 warnings in Run 6 are 何 = ナン false positives.

Other observations:

- 水を食べますか ("do you eat water?") passes every check. It is grammatical but semantically odd,
  unless the listener is an alien visiting Earth (owner's comment).
  Whether an odd sentence is a bad exercise depends on context. That is a teacher decision, not a rule.
- The forbidden kanji stay the main rejection cause: 学校, 飯, 達, 誰.

## Wrong answers and what we tuned


Live model output that was wrong or weak:

| Model | Output | Problem | Response |
|---|---|---|---|
| Gemma | `私 は 水 を 飲 む。` (all 10, twice) | Spaces between characters | Whitespace rule rejects it; prompt now forbids spaces |
| Gemma | Response after the prompt change | Not valid JSON (one of two attempts) | `InvalidResponseError`; the caller retried |
| Gemma | `茶を飲みます` → `おちゃをのみます` | Reading adds お, which is not in jp | Not detectable by structure; teacher review |
| Gemma | `友と食べます` → `ともだちとたべます` | 友 alone is とも; ともだち needs 友達 | Not detectable by structure; teacher review |
| Gemma | `毎日は食べます` | Unnatural は; natural is 毎日食べます | Not checked; teacher review |
| Gemma | 友達, 一緒, 食事, ご飯 (after the kana fallback line) | Forbidden kanji 達, 一, 緒, 事, 飯 | Validator rejects the result |
| Gemma | Empty content (0 characters) | Thinking filled the 16384-token context | Adapter disables thinking by default |
| Gemma | `友人は水を飲む` → `ゆうじんlyはみずをのむ` | Latin letters in the reading | New reading character rule rejects it |
| Gemma | `わたしは みずを のみます` | Spaces in the reading | New reading character rule rejects it |
| Gemma | `毎日食べます` → `まいにちはたべます` | Reading adds は, which is not in jp | Not detectable by structure; dictionary check (to do) |
| Gemma | `人は何を飲む` → `なにおをのむ` | Wrong reading; correct is なにをのむ | Not detectable by structure; teacher review |
| Gemma | `何を食べる?` → `なにをたべる。` | `?` in jp, `。` in reading | Not checked; teacher review |
| Gemma | "Jeść z przyjacielem", "Pić wodę rano" | Polish infinitives, inconsistent person | Translation quality is not validated |
| Gemma | 友達 (Run 4, 2 of 3 attempts) | Forbidden kanji 達 | Validator rejects the result; prompt tuning (to do) |
| Gemma | `今、水を見ます。`, `今、茶を見ます。` | Unnatural object for 見る | Not checked; teacher review |
| Gemma | 行 3 times, 来 once in 10 sentences | Targets not balanced | Not checked; prompt tuning (to do) |
| Qwen | `私は学校にいく。` | いく in kana although 行 was allowed | Accepted; kana is permitted |
| Qwen | 日本人 → "osoba japońska" | Unnatural Polish; natural is "Japończyk" | Translation quality is not validated |
| Qwen | 3 sentences in 3:21 | Dense 27B spills out of 16 GB VRAM | Changed to Gemma 4 26B MoE QAT |

Wrong assumptions found during development (before any live run):

| What we assumed | What was true | Fix |
|---|---|---|
| `/\p{Han}/` finds every kanji-like character | 〆 (U+3006) is `Ideographic`, not `Han` | `HAN = /[\p{Han}\p{Ideographic}]/` |
| `\p{Ideographic}` alone is enough | It misses 々 and Kangxi radicals; ⼈ (U+2F08) looks the same as 人 | Use both properties; accept only U+4E00..U+9FFF |
| A test with `{ invalid: "request" }` proves validation | A validator that rejects everything also passed | Each test changes one field of a valid baseline |
| Trust the model's `target_kanji` declaration | Declarations can disagree with the text | Rules read kanji from the actual `jp` |
| Normalize text with NFC | NFC changes CJK compatibility ideographs to other code points | Reject compatibility ideographs; no normalization |

Rejected tuning: a required politeness level. Owner decision: only the allowed-kanji list restricts content.
Plain form and です/ます form are both correct when the sentence is natural.

## To do before the post

- Teacher feedback (first user): would they use it, would they pay, what do they ask for next.
- Public repository link.
- Terminal recording of the demo with asciinema 3.2.1 (Rust rewrite, pinned in `mise.toml`).
  Run it from the project directory so the mise shims resolve.
