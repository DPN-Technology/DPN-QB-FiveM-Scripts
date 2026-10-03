# Training Academy Session Authority Hardening Contract

Baseline: `main` at `6bea5b82dd09764584e9e6ea9664c23a15b580e4`.

## Current finding

Current `dpn-training-academy/server/main.lua` verifies instructor role for `gradeScenario` and `endSession`, but still does not prove that the caller owns the referenced instructor-created session.

`gradeScenario` also validates that the target is an online LEO but does not prove that the target is enrolled in `session.trainees`.

External/system scenarios continue to use `instructor = 0`, so hardening must preserve explicit server-owned compatibility for those paths.

## Required invariants

- Instructor-created session mutations require `session.instructor == source` or equivalent authoritative ownership.
- Grading additionally requires authoritative trainee membership.
- Missing, stale, closed, wrong-type, cross-instructor, and non-member mutations fail closed.
- Session closure clears or updates ownership indexes consistently.
- Existing events, UI workflows, course scoring, certifications, dispatch integration, external scenario exports, audit records, and unique functionality remain intact.
- Add focused Quality Gate coverage for ownership and membership checks.
