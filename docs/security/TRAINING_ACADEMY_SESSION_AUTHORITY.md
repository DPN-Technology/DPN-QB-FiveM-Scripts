# Training Academy Session Authority Hardening Contract

## Scope

This document defines the server-authority requirements for Training Academy scenario grading and session closure in `dpn-training-academy`.

The current runtime already verifies that callers are instructors before grading or closing sessions. The remaining authority gap is session ownership and target membership: an instructor can currently submit a valid active session ID they do not own, grade an arbitrary online LEO target, or close another instructor's active session.

This phase is preparation only. It intentionally does not alter runtime behavior, remove features, change event names, or weaken existing CI.

## Current risk

The server handlers for:

- `dpn-training-academy:server:gradeScenario`
- `dpn-training-academy:server:endSession`

validate instructor role but do not currently require the calling instructor to own the referenced session. `gradeScenario` also accepts any online LEO server ID without proving that the target is enrolled in the referenced scenario.

That means possession or discovery of another active session ID is sufficient for one instructor to affect another instructor's training record or lifecycle.

## Required server-authority invariants

### 1. Session ownership

For instructor-owned scenarios, mutating actions MUST prove that the caller owns the session.

Acceptable ownership evidence is the server-maintained session state created when the scenario is staged, for example:

- `session.instructor == source`, and/or
- `InstructorSessions[source] == sessionId`

The authoritative decision must be made server-side. Client-submitted instructor identities must never be trusted.

System-created/external scenarios with `instructor == 0` must remain compatible with existing export-driven workflows. Any special administrative/system mutation path must remain explicit and server-owned.

### 2. Trainee membership

Scenario grading MUST only target a trainee who is enrolled in the referenced session.

The server must verify both:

- the target still resolves to a valid LEO player where required by existing behavior; and
- the target's authoritative identity/server ID is represented in the session's trainee membership state.

A caller must not be able to grade an arbitrary online LEO merely by supplying that player's server ID.

### 3. Session lifecycle

Only the session owner (or an explicitly authorized server/system path) may transition an instructor-owned session to `closed`.

Closing a session must also maintain the existing `InstructorSessions` ownership index so stale ownership mappings do not survive after closure.

Repeated or stale close requests should fail closed without altering unrelated sessions.

### 4. State validation

Mutating handlers must reject invalid or inappropriate session states. At minimum:

- missing session IDs fail closed;
- closed/completed sessions cannot be re-graded unless an explicitly documented workflow allows it;
- course sessions must not be mutated through scenario-only grading paths;
- scenario grading must target the referenced scenario rather than another active session.

### 5. Audit integrity

Existing audit logging must be preserved. Rejected cross-session/cross-instructor mutations should be safe to log where useful without exposing sensitive data.

Successful grading records must continue to identify the real server-authorized instructor, target identity, score, and session.

### 6. Compatibility requirements

Hardening must preserve:

- existing event names and client compatibility;
- instructor UI workflows;
- course scoring and certification behavior;
- scenario creation and dispatch integration;
- database schemas unless a schema change is independently justified;
- external/system scenario creation export behavior;
- existing notifications and audit records where semantically valid;
- all unique Training Academy functionality.

No unique feature may be removed to simplify authority enforcement.

## Recommended implementation shape

A small reusable server helper should centralize session mutation authorization, for example conceptually:

1. normalize and resolve `sessionId`;
2. require an existing session;
3. require the correct session type/state for the requested action;
4. verify instructor role;
5. verify `session.instructor == source` for instructor-owned sessions;
6. verify target membership for grading;
7. perform the existing mutation only after every check succeeds.

This avoids duplicating subtly different ownership logic between `gradeScenario` and `endSession`.

## Regression coverage

Implementation must add focused CI coverage that fails if either protected handler regresses to role-only authorization.

The guard should verify, at minimum, that:

- grading checks authoritative session ownership;
- grading checks trainee membership;
- session closure checks authoritative session ownership;
- external/system scenario compatibility remains intentional;
- the new guard is added to the existing DPN Quality Gate without removing or weakening any existing validation step.

Runtime tests should also cover:

- owner instructor grades an enrolled trainee: allowed;
- non-owner instructor attempts grading: rejected;
- owner instructor grades non-member LEO: rejected;
- owner instructor closes owned session: allowed;
- non-owner instructor closes session: rejected;
- stale/missing/closed session mutation: rejected;
- system-created scenario behavior remains compatible with approved server-owned paths.

## Acceptance criteria

This hardening is complete only when the server—not the client—proves instructor ownership, trainee membership, session type/state, and target validity before grading or session closure, with additive regression coverage passing alongside every existing repository check.
