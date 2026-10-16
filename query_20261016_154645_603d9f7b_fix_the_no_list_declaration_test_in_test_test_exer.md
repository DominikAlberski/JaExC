---
type: "query"
date: "2026-10-16T15:46:45.359271+00:00"
question: "Fix the no-list declaration test in test/test_exercise_validator.rb"
contributor: "graphify"
outcome: "useful"
source_nodes: ["test_test_creator", "test_test_exercise_validator"]
---

# Q: Fix the no-list declaration test in test/test_exercise_validator.rb

## Answer

Goal: Fix one wrong expectation from task 22c2a046. Inputs: Branch task/22c2a046 holds the V1 tests. Your task branch starts from the goal branch. First run git cherry-pick 42e0a32 so that your branch holds the V1 tests. The wrong test is test_wrong_declaration_error_has_no_list_when_no_kanji_can_be_reported. Its jp 日本です。 contains the request target 本, and 本 is not declared. Plan section V says the kanji list then holds 本. Change the test so that the kanji list is really empty: use a jp with no request target, for example 日です。, and a declared entry that is not one kanji. That exercise also has a missing_target violation. Assert the full errors Array in rule order. Keep the regression intent: the declared String must not appear. Out of scope: All other tests and all files under lib/. Acceptance: (1) bundle exec ruby -Itest test/test_exercise_validator.rb exits nonzero with NameErrors only and 0 assertion failures. (2) bundle exec rake test reports 0 failures, and its errors are only the 14 new V1 tests. (3) bundle exec rubocop reports no offenses. Report format: Annotate the summary line of each command, numbered 1 to 3. Add a TESTS line. Then run coord done.
1. TESTS: ExerciseValidator: 12 runs, 0 assertions, 0 failures, 12 NameErrors for missing constants. 2. TESTS: rake test: 93 runs, 251 assertions, 0 failures, 14 errors; all errors are the new V1 tests. 3. TESTS: rubocop: 29 files inspected, no offenses. TESTS: test_wrong_declaration_error_has_no_list_when_no_kanji_can_be_reported asserts missing_target before an empty wrong_target_declaration line and excludes the declaration from violations and message. Graph: fresh.

## Outcome

- Signal: useful

## Source Nodes

- test_test_creator
- test_test_exercise_validator