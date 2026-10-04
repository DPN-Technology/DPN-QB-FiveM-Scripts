#!/usr/bin/env python3
from pathlib import Path
import sys

SERVER = Path('qbcore/public-safety/dpn-unified-emergency-services-suite/[dpn-lawenforcement]/dpn-training-academy/server/main.lua')
CLIENT = Path('qbcore/public-safety/dpn-unified-emergency-services-suite/[dpn-lawenforcement]/dpn-training-academy/client/main.lua')
APP = Path('qbcore/public-safety/dpn-unified-emergency-services-suite/[dpn-lawenforcement]/dpn-training-academy/html/app.js')


def fail(message: str) -> None:
    print(f'[training-session-authority] ERROR: {message}')
    sys.exit(1)


def event_block(text: str, event: str, next_event: str) -> str:
    start = text.find(event)
    if start < 0:
        fail(f'missing event {event}')
    end = text.find(next_event, start + len(event))
    if end < 0:
        fail(f'missing next event boundary {next_event}')
    return text[start:end]


def main() -> None:
    for path in (SERVER, CLIENT, APP):
        if not path.is_file():
            fail(f'missing {path}')

    server = SERVER.read_text(encoding='utf-8')
    client = CLIENT.read_text(encoding='utf-8')
    app = APP.read_text(encoding='utf-8')

    required_server = {
        'instructor/admin tool boundary': 'local function canUseInstructorTools(src)',
        'scenario ownership helper': 'local function canManageScenario(src, session)',
        'instructor ownership binding': 'session.instructor == src and InstructorSessions[src] == session.id',
        'system scenario admin boundary': 'session.instructor == 0 and isAcademyAdmin(src)',
        'stable trainee identity lookup': 'local identifier = DPN.Bridge.GetIdentifier(targetServerId)',
        'explicit trainee management event': "RegisterNetEvent('dpn-training-academy:server:setScenarioTrainee'",
        'enrollment by identifier': 'session.trainees[identifier] = {',
        'removal by identifier': 'session.trainees[identifier] = nil',
        'single active instructor scenario guard': "End active scenario %s before creating another.",
        'disconnect abandonment': "session.status = 'abandoned'",
        'ownership index cleanup': 'InstructorSessions[src] = nil',
        'external owner resource audit context': "ownerResource = clean(GetInvokingResource() or 'dpn-training-academy', 120)",
    }
    missing = [name for name, needle in required_server.items() if needle not in server]
    if missing:
        fail('missing required server controls: ' + ', '.join(missing))

    grade = event_block(
        server,
        "RegisterNetEvent('dpn-training-academy:server:gradeScenario'",
        "RegisterNetEvent('dpn-training-academy:server:endSession'"
    )
    for needle in (
        'if not canManageScenario(src, session) then',
        'local trainee, identifier = enrolledTrainee(session, targetServerId)',
        "Target must be enrolled in this scenario before grading.",
    ):
        if needle not in grade:
            fail(f'gradeScenario missing authority control: {needle}')

    end_session = event_block(
        server,
        "RegisterNetEvent('dpn-training-academy:server:endSession'",
        "AddEventHandler('playerDropped'"
    )
    if 'if not canManageScenario(src, session) then' not in end_session:
        fail('endSession does not enforce scenario ownership')
    if 'InstructorSessions[src] = nil' not in end_session:
        fail('endSession does not clear the instructor ownership index')

    if "RegisterNUICallback('setScenarioTrainee'" not in client:
        fail('client is missing the trainee enrollment callback')
    if 'viewerSource = src' not in server or 'academyAdmin = isAcademyAdmin(src)' not in server:
        fail('server does not publish viewer authority context to the instructor UI')
    if 'Number(s.instructor) === Number(state.viewerSource)' not in app:
        fail('instructor UI does not filter sessions to the authorized owner/admin view')
    for needle in ("post('setScenarioTrainee'", "post('gradeScenario'", "post('endSession'"):
        if needle not in app:
            fail(f'instructor UI missing managed scenario action: {needle}')

    print('[training-session-authority] PASS: scenario ownership, enrollment, grading membership, cleanup, and UI control paths are enforced')


if __name__ == '__main__':
    main()
