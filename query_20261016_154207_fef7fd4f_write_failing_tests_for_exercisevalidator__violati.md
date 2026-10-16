---
type: "query"
date: "2026-10-16T15:42:07.971353+00:00"
question: "Write failing tests for ExerciseValidator, Violation, and InvalidExerciseError"
contributor: "graphify"
outcome: "useful"
source_nodes: ["test_test_creator", "test_test_exercise_validator"]
---

# Q: Write failing tests for ExerciseValidator, Violation, and InvalidExerciseError

## Answer

Goal: Write the failing tests for stream V of goal 805d4501. The tests define the domain validator. Load the ruby-code-rules skill. Write no plain comments. Inputs: $COORD_DIR/artifacts/805d4501/plan.md, section V and section "Streams and order". The section V table gives the six rules, the rule codes, the kanji values, the order, and the line formats. Reference only: $COORD_DIR/artifacts/805d4501/found-uncommitted/test_exercise_validator.rb. Reuse its test cases where they match section V. The reference differs on the error data and the message. Section V wins. Existing code: lib/jaexc/response_parser.rb, lib/jaexc/errors.rb, lib/jaexc/creator.rb, test/test_creator.rb.
Test content: Cover each rule with one rejected case and one accepted case. Cover 々 in jp as accepted. Cover 〆, 〇, 㐀, 侮, and ⼈ as unsupported. Cover 々 in reading as kanji_in_reading. Cover a repeated declaration. Cover the order of violations across two exercises. Cover each line format. Cover that violations is frozen and that content is nil. Cover that InvalidExerciseError is a subclass of InvalidResponseError. Cover that the message has the parent format. Add two regression tests. One declares a long String in target_kanji. One declares a String with an embedded newline. Each declaration is wrong. The violation, errors, and message must not contain that String. In test/test_creator.rb, add test_constraint_violation_raises_invalid_exercise_error. Reference new constants only inside tests or setup, not at file top level.
Out of scope: All files under lib/. Tests for Result, the CLI, and mutant. Do not change existing tests in test/test_creator.rb. Acceptance: Run each command and check the result. (1) bundle exec ruby -Itest test/test_exercise_validator.rb exits nonzero. Each problem is a NameError for JaExC::ExerciseValidator, JaExC::InvalidExerciseError, or JaExC::Violation. There are 0 assertion failures. (2) bundle exec ruby -Itest test/test_violation.rb exits nonzero with NameError for JaExC::V

## Outcome

- Signal: useful

## Source Nodes

- test_test_creator
- test_test_exercise_validator