# Training Academy Session Authority Hardening Contract

Baseline refreshed from `main` at `2d88c57091f178ceb964feaf4df1f5f52c8afc1e`.

## Resolution

Instructor scenario mutations now use a server-authoritative ownership and membership model.

- Instructor-created scenarios are bound to both `session.instructor` and `InstructorSessions[source]`.
- An instructor cannot create a second active scenario until the current one is closed or abandoned.
- Trainee enrollment and removal are explicit server events controlled by the scenario owner.
- Trainees are keyed by the server-derived persistent player identifier rather than trusting a client ownership claim.
- `gradeScenario` fails closed unless the caller owns the active scenario and the target is currently online, eligible, and enrolled in that exact session.
- `endSession` requires the same ownership authority and clears the instructor ownership index.
- Instructor disconnects mark their still-open scenario `abandoned`, preventing orphaned mutable sessions.
- System-created scenarios remain `instructor = 0`; only holders of the configured academy admin ACE can manage them through player-facing mutation events.
- External/system scenario creation records the invoking resource as `ownerResource` for audit context.

## Preserved behavior

Course scoring, certifications, dispatch integration, external scenario creation, SQL audit records, NUI workflows, and existing event names remain intact. The instructor UI now exposes explicit trainee enrollment/removal and scenario closure so the authoritative membership contract is usable in normal gameplay.

## Regression coverage

`tools/check_training_academy_session_authority.py` is wired into DPN Quality Gate and fails when session ownership, enrollment authority, grade membership checks, ownership-index cleanup, or the NUI enrollment path is removed.
