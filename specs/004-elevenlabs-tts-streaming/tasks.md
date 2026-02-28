# Tasks: ElevenLabs TTS Streaming

**Input**: Design documents from `/specs/004-elevenlabs-tts-streaming/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/tts-api.yaml

**Tests**: Unit tests for text preprocessing included per plan.md constitution check (TDD for critical logic).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4)
- Include exact file paths in descriptions

## Path Conventions

- **Backend**: `backend/src/`, `backend/tests/`
- **iOS**: `ios/lib/`, `ios/ios/Runner/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and dependencies

- [x] T001 [P] Add ElevenLabs settings to backend/src/core/config.py (elevenlabs_api_key, elevenlabs_voice_id, elevenlabs_model_id, tts_max_text_length, tts_chunk_size)
- [x] T002 [P] Add just_audio ^0.9.36 and audio_session ^0.1.18 dependencies to ios/pubspec.yaml
- [x] T003 [P] Add UIBackgroundModes audio to ios/ios/Runner/Info.plist

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core TTS infrastructure that MUST be complete before ANY user story

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Backend TTS Service

- [x] T004 [P] Create TTSStreamRequest and TTSErrorResponse schemas in backend/src/schemas/tts.py per data-model.md
- [x] T005 [P] Create TTSStatusResponse schema in backend/src/schemas/tts.py per contracts/tts-api.yaml
- [x] T006 Create TTSService class in backend/src/services/tts_service.py with text preprocessing (strip markdown, remove DICE tags, normalize whitespace)
- [x] T007 Add text chunking logic to TTSService in backend/src/services/tts_service.py (split by sentence boundaries for texts > tts_chunk_size)
- [x] T008 Implement ElevenLabs streaming proxy in TTSService using httpx async streaming in backend/src/services/tts_service.py
- [x] T009 Add error handling for rate_limit, quota_exceeded, api_error in backend/src/services/tts_service.py
- [x] T010 Create POST /tts/stream endpoint in backend/src/api/routes/tts.py with StreamingResponse
- [x] T011 Create GET /tts/status endpoint in backend/src/api/routes/tts.py
- [x] T012 Register TTS router in backend/src/api/main.py
- [x] T013 [P] Write unit tests for text preprocessing in backend/tests/unit/test_tts_service.py

### Flutter Audio Infrastructure

- [x] T014 Create TTSStatus enum and TTSState freezed model in ios/lib/features/game_session/bloc/tts_state.dart
- [x] T015 Run flutter pub run build_runner build --delete-conflicting-outputs to generate tts_state.freezed.dart
- [x] T016 Create TTSApi class in ios/lib/features/game_session/data/tts_api.dart for streaming HTTP requests
- [x] T017 Create TTSCubit with AudioPlayer initialization in ios/lib/features/game_session/bloc/tts_cubit.dart
- [x] T018 Add audio session configuration and interruption handling to TTSCubit in ios/lib/features/game_session/bloc/tts_cubit.dart
- [x] T019 Register TTSCubit as singleton in ios/lib/core/di/injection.dart

**Checkpoint**: Foundation ready - TTS endpoint returns streaming audio, Flutter can play audio from URL

---

## Phase 3: User Story 1 - Прослушивание сообщения DM (Priority: P1) 🎯 MVP

**Goal**: Пользователь нажимает кнопку "Прослушать" и аудио начинает воспроизводиться в течение 3 секунд

**Independent Test**: Открыть игровую сессию с сообщениями DM, нажать кнопку "Прослушать", проверить что аудио воспроизводится

### Implementation for User Story 1

- [x] T020 [US1] Add playMessage method to TTSCubit that sends text to backend and plays streaming audio in ios/lib/features/game_session/bloc/tts_cubit.dart
- [x] T021 [US1] Create TTSButton widget with play icon in ios/lib/features/game_session/ui/widgets/tts_button.dart
- [x] T022 [US1] Add TTSButton to _DmBubble in ios/lib/features/game_session/ui/widgets/message_bubble.dart (show only for MessageRole.dm)
- [x] T023 [US1] Connect TTSButton to TTSCubit.playMessage with message.content and message.id (server handles markdown stripping via T006)

**Checkpoint**: User Story 1 complete - можно прослушать любое сообщение DM

---

## Phase 4: User Story 2 - Остановка воспроизведения (Priority: P1)

**Goal**: Пользователь может остановить воспроизведение в любой момент нажатием той же кнопки

**Independent Test**: Запустить воспроизведение, нажать кнопку стоп, проверить что аудио останавливается в течение 500мс

### Implementation for User Story 2

- [x] T025 [US2] Add stopPlayback method to TTSCubit in ios/lib/features/game_session/bloc/tts_cubit.dart
- [x] T026 [US2] Ensure stopPlayback closes HTTP stream and releases AudioPlayer resources
- [x] T027 [US2] Update TTSButton to show stop icon when status == playing, call stopPlayback on tap in ios/lib/features/game_session/ui/widgets/tts_button.dart
- [x] T028 [US2] Add debounce (300ms) to prevent rapid tap issues in TTSButton

**Checkpoint**: User Story 2 complete - воспроизведение можно остановить

---

## Phase 5: User Story 3 - Визуальная индикация состояния (Priority: P2)

**Goal**: Пользователь видит текущее состояние воспроизведения (idle/loading/playing/error)

**Independent Test**: Запустить воспроизведение и проверить смену иконки/анимации на кнопке

### Implementation for User Story 3

- [x] T029 [US3] Add loading state (CircularProgressIndicator) to TTSButton when status == loading in ios/lib/features/game_session/ui/widgets/tts_button.dart
- [x] T030 [US3] Add play/stop icon transition animation to TTSButton
- [x] T031 [US3] Add error state display (red icon, tooltip with errorMessage) to TTSButton
- [x] T032 [US3] Update TTSButton to use BlocBuilder<TTSCubit, TTSState> for reactive UI updates

**Checkpoint**: User Story 3 complete - состояние воспроизведения визуально понятно

---

## Phase 6: User Story 4 - Воспроизведение только одного сообщения (Priority: P2)

**Goal**: При запуске нового воспроизведения предыдущее автоматически останавливается

**Independent Test**: Запустить воспроизведение сообщения A, нажать "Прослушать" на сообщении B, проверить что A остановилось

### Implementation for User Story 4

- [x] T033 [US4] Modify playMessage in TTSCubit to call stopPlayback before starting new playback in ios/lib/features/game_session/bloc/tts_cubit.dart
- [x] T034 [US4] Track currentMessageId in TTSState to identify which message is currently playing
- [x] T035 [US4] Update TTSButton to check if this message is the currently playing one and show appropriate icon

**Checkpoint**: User Story 4 complete - только одно сообщение воспроизводится одновременно

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Edge cases, error handling, and final polish

### Error Handling

- [x] T036 [P] Add rate limit error handling in TTSCubit with "Превышен лимит прослушиваний, попробуйте позже (через минуту)" message
- [x] T037 [P] Add quota exceeded handling - hide TTS buttons when status endpoint returns available=false
- [x] T038 [P] Add network error handling with user-friendly message in TTSCubit
- [x] T039 Check TTS status on app launch and hide buttons if unavailable in GameSessionBloc or TTSCubit init

### Background & Interruption Handling

- [x] T040 Configure audio session for background playback in TTSCubit (AVAudioSession category: playback)
- [x] T041 Handle audio interruption (phone call, Siri): pause playback, set wasPlayingBeforeInterruption flag
- [x] T042 Auto-resume playback after interruption ends if wasPlayingBeforeInterruption was true

### Cleanup & Edge Cases

- [x] T043 Stop playback when user leaves game session (dispose TTSCubit or listen to navigation events)
- [x] T044 Clear TTS state on user logout in TTSCubit
- [x] T045 Handle very short messages (< 10 chars) - ensure they play normally without special handling

### Verification

- [x] T046 Manual test: phone call interruption and resume on real iOS device
- [x] T047 Manual test: Siri activation and resume
- [x] T048 Manual test: background/foreground transitions
- [x] T049 Manual test: low connectivity (3G simulation)
- [x] T050 Run quickstart.md validation steps

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup - BLOCKS all user stories
- **User Stories (Phase 3-6)**: All depend on Foundational phase completion
  - US1 and US2 are both P1, can be done sequentially
  - US3 and US4 are both P2, can be done after US1/US2
- **Polish (Phase 7)**: Depends on all user stories complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational - No dependencies on other stories
- **User Story 2 (P1)**: Can start after Foundational - Builds on TTSCubit from US1
- **User Story 3 (P2)**: Can start after US1/US2 - Enhances TTSButton
- **User Story 4 (P2)**: Can start after US1 - Modifies playMessage logic

### Within Each Phase

- Backend tasks can run in parallel with Flutter tasks (different projects)
- T004, T005 can run in parallel (different schemas in same file but independent)
- T014-T019 must be sequential (state → cubit → DI)
- Models before services, services before endpoints

### Parallel Opportunities

- All Setup tasks (T001-T003) can run in parallel
- Backend schema tasks (T004, T005) can run in parallel
- Backend tests (T013) can run in parallel with Flutter setup (T014-T019)
- Error handling tasks (T036-T038) can run in parallel

---

## Parallel Example: Phase 2 Backend + Flutter

```bash
# Launch backend schema tasks together:
Task: "Create TTSStreamRequest and TTSErrorResponse schemas in backend/src/schemas/tts.py"
Task: "Create TTSStatusResponse schema in backend/src/schemas/tts.py"

# Launch Flutter state tasks while backend service is being built:
Task: "Create TTSStatus enum and TTSState freezed model in ios/lib/features/game_session/bloc/tts_state.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 + 2 Only)

1. Complete Phase 1: Setup (T001-T003)
2. Complete Phase 2: Foundational (T004-T019)
3. Complete Phase 3: User Story 1 (T020-T023)
4. Complete Phase 4: User Story 2 (T025-T028)
5. **STOP and VALIDATE**: Test play/stop functionality
6. Deploy/demo if ready - basic TTS is functional

### Full Feature Delivery

1. Complete MVP (US1 + US2)
2. Add User Story 3: Visual states (T029-T032)
3. Add User Story 4: Single playback (T033-T035)
4. Complete Polish phase (T036-T050)
5. Full feature ready

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- US1 and US2 together form the MVP (basic play/stop)
- US3 and US4 are polish features (visual feedback, single playback)
- Backend and Flutter can be developed in parallel after Phase 1
- Commit after each task or logical group
- Test on real device for interruption handling (T046-T049)
