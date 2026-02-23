import 'package:ai_dungeon_master/core/storage/secure_storage.dart';
import 'package:ai_dungeon_master/features/lobby/bloc/lobby_bloc.dart';
import 'package:ai_dungeon_master/features/lobby/bloc/lobby_event.dart';
import 'package:ai_dungeon_master/features/lobby/bloc/lobby_state.dart';
import 'package:ai_dungeon_master/features/lobby/data/lobby_repository.dart';
import 'package:ai_dungeon_master/features/lobby/models/room.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLobbyRepository extends Mock implements LobbyRepository {}

class MockSecureStorage extends Mock implements SecureStorage {}

void main() {
  late LobbyRepository lobbyRepository;
  late SecureStorage secureStorage;
  late LobbyBloc lobbyBloc;

  final testRoomSummary = RoomSummary(
    id: 'room-1',
    name: 'Test Room',
    scenarioTitle: 'Dragon Quest',
    hostName: 'Host User',
    playerCount: 2,
    maxPlayers: 5,
    status: 'waiting',
  );

  final testRoomPlayer = RoomPlayer(
    id: 'player-1',
    userId: 'user-1',
    name: 'Host User',
    status: 'approved',
    isHost: true,
  );

  final testRoom = Room(
    id: 'room-1',
    name: 'Test Room',
    status: 'waiting',
    maxPlayers: 5,
    players: [testRoomPlayer],
    createdAt: DateTime.now(),
  );

  final testGameSession = GameSessionResponse(
    id: 'session-1',
    roomId: 'room-1',
    worldState: {'current_act': 'act_1'},
    startedAt: DateTime.now(),
  );

  setUp(() {
    lobbyRepository = MockLobbyRepository();
    secureStorage = MockSecureStorage();
    when(() => secureStorage.getUserId()).thenAnswer((_) async => 'user-1');
    lobbyBloc = LobbyBloc(lobbyRepository, secureStorage);
  });

  tearDown(() {
    lobbyBloc.close();
  });

  group('LobbyBloc', () {
    test('initial state is LobbyInitial', () {
      expect(lobbyBloc.state, const LobbyState.initial());
    });

    group('LoadRooms', () {
      blocTest<LobbyBloc, LobbyState>(
        'emits [loading, loaded] when rooms load successfully',
        build: () {
          when(() => lobbyRepository.listRooms(status: any(named: 'status')))
              .thenAnswer((_) async => [testRoomSummary]);
          return lobbyBloc;
        },
        act: (bloc) => bloc.add(const LobbyEvent.loadRooms()),
        expect: () => [
          const LobbyState.loading(),
          LobbyState.loaded(rooms: [testRoomSummary]),
        ],
      );

      blocTest<LobbyBloc, LobbyState>(
        'emits [loading, error] when rooms load fails',
        build: () {
          when(() => lobbyRepository.listRooms(status: any(named: 'status')))
              .thenThrow(Exception('Network error'));
          return lobbyBloc;
        },
        act: (bloc) => bloc.add(const LobbyEvent.loadRooms()),
        expect: () => [
          const LobbyState.loading(),
          isA<LobbyError>(),
        ],
      );

      blocTest<LobbyBloc, LobbyState>(
        'emits [loading, loaded] with empty list when no rooms',
        build: () {
          when(() => lobbyRepository.listRooms(status: any(named: 'status')))
              .thenAnswer((_) async => []);
          return lobbyBloc;
        },
        act: (bloc) => bloc.add(const LobbyEvent.loadRooms()),
        expect: () => [
          const LobbyState.loading(),
          const LobbyState.loaded(rooms: []),
        ],
      );
    });

    group('CreateRoom', () {
      blocTest<LobbyBloc, LobbyState>(
        'emits [creating, roomDetail] when room created successfully',
        build: () {
          when(() => lobbyRepository.createRoom(
                name: any(named: 'name'),
                scenarioVersionId: any(named: 'scenarioVersionId'),
                maxPlayers: any(named: 'maxPlayers'),
              )).thenAnswer((_) async => testRoom);
          return lobbyBloc;
        },
        act: (bloc) => bloc.add(const LobbyEvent.createRoom(
          name: 'New Room',
          scenarioVersionId: 'version-1',
          maxPlayers: 4,
        )),
        expect: () => [
          const LobbyState.creating(),
          isA<LobbyRoomDetail>(),
        ],
      );

      blocTest<LobbyBloc, LobbyState>(
        'emits [creating, error] when room creation fails',
        build: () {
          when(() => lobbyRepository.createRoom(
                name: any(named: 'name'),
                scenarioVersionId: any(named: 'scenarioVersionId'),
                maxPlayers: any(named: 'maxPlayers'),
              )).thenThrow(Exception('Failed'));
          return lobbyBloc;
        },
        act: (bloc) => bloc.add(const LobbyEvent.createRoom(
          name: 'New Room',
          scenarioVersionId: 'version-1',
        )),
        expect: () => [
          const LobbyState.creating(),
          isA<LobbyError>(),
        ],
      );
    });

    group('LoadRoom', () {
      blocTest<LobbyBloc, LobbyState>(
        'emits [loading, roomDetail] when room loaded',
        build: () {
          when(() => lobbyRepository.getRoom(any()))
              .thenAnswer((_) async => testRoom);
          return lobbyBloc;
        },
        act: (bloc) => bloc.add(const LobbyEvent.loadRoom(roomId: 'room-1')),
        expect: () => [
          const LobbyState.loading(),
          isA<LobbyRoomDetail>(),
        ],
      );
    });

    group('JoinRoom', () {
      blocTest<LobbyBloc, LobbyState>(
        'emits [loading, roomDetail] when join succeeds',
        build: () {
          when(() => lobbyRepository.joinRoom(any()))
              .thenAnswer((_) async {});
          when(() => lobbyRepository.getRoom(any()))
              .thenAnswer((_) async => testRoom);
          return lobbyBloc;
        },
        act: (bloc) => bloc.add(const LobbyEvent.joinRoom(roomId: 'room-1')),
        expect: () => [
          const LobbyState.loading(),
          isA<LobbyRoomDetail>(),
        ],
      );

      blocTest<LobbyBloc, LobbyState>(
        'emits [loading, error] when join fails',
        build: () {
          when(() => lobbyRepository.joinRoom(any()))
              .thenThrow(Exception('Room full'));
          return lobbyBloc;
        },
        act: (bloc) => bloc.add(const LobbyEvent.joinRoom(roomId: 'room-1')),
        expect: () => [
          const LobbyState.loading(),
          isA<LobbyError>(),
        ],
      );
    });

    group('ApprovePlayer', () {
      blocTest<LobbyBloc, LobbyState>(
        'emits [roomDetail] when player approved',
        build: () {
          when(() => lobbyRepository.approvePlayer(any(), any()))
              .thenAnswer((_) async {});
          when(() => lobbyRepository.getRoom(any()))
              .thenAnswer((_) async => testRoom);
          return lobbyBloc;
        },
        act: (bloc) => bloc.add(const LobbyEvent.approvePlayer(
          roomId: 'room-1',
          playerId: 'player-2',
        )),
        expect: () => [isA<LobbyRoomDetail>()],
      );
    });

    group('DeclinePlayer', () {
      blocTest<LobbyBloc, LobbyState>(
        'emits [roomDetail] when player declined',
        build: () {
          when(() => lobbyRepository.declinePlayer(any(), any()))
              .thenAnswer((_) async {});
          when(() => lobbyRepository.getRoom(any()))
              .thenAnswer((_) async => testRoom);
          return lobbyBloc;
        },
        act: (bloc) => bloc.add(const LobbyEvent.declinePlayer(
          roomId: 'room-1',
          playerId: 'player-2',
        )),
        expect: () => [isA<LobbyRoomDetail>()],
      );
    });

    group('ToggleReady', () {
      blocTest<LobbyBloc, LobbyState>(
        'emits [roomDetail] when ready toggled',
        build: () {
          when(() => lobbyRepository.toggleReady(
                roomId: any(named: 'roomId'),
                characterId: any(named: 'characterId'),
                ready: any(named: 'ready'),
              )).thenAnswer((_) async {});
          when(() => lobbyRepository.getRoom(any()))
              .thenAnswer((_) async => testRoom);
          return lobbyBloc;
        },
        act: (bloc) => bloc.add(const LobbyEvent.toggleReady(
          roomId: 'room-1',
          characterId: 'char-1',
          ready: true,
        )),
        expect: () => [isA<LobbyRoomDetail>()],
      );
    });

    group('StartGame', () {
      blocTest<LobbyBloc, LobbyState>(
        'emits [gameStarting] when game starts',
        build: () {
          when(() => lobbyRepository.startGame(any()))
              .thenAnswer((_) async => testGameSession);
          when(() => lobbyRepository.getRoom(any()))
              .thenAnswer((_) async => testRoom);
          return lobbyBloc;
        },
        act: (bloc) =>
            bloc.add(const LobbyEvent.startGame(roomId: 'room-1')),
        expect: () => [isA<LobbyGameStarting>()],
      );

      blocTest<LobbyBloc, LobbyState>(
        'emits [error] when start fails',
        build: () {
          when(() => lobbyRepository.startGame(any()))
              .thenThrow(Exception('Not all ready'));
          return lobbyBloc;
        },
        act: (bloc) =>
            bloc.add(const LobbyEvent.startGame(roomId: 'room-1')),
        expect: () => [isA<LobbyError>()],
      );
    });

    group('ClearError', () {
      blocTest<LobbyBloc, LobbyState>(
        'emits [initial] when error cleared',
        build: () => lobbyBloc,
        act: (bloc) => bloc.add(const LobbyEvent.clearError()),
        expect: () => [const LobbyState.initial()],
      );
    });
  });
}
