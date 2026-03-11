import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../core/storage/secure_storage.dart';
import '../data/lobby_repository.dart';
import '../models/room.dart';
import 'lobby_event.dart';
import 'lobby_state.dart';

@injectable
class LobbyBloc extends Bloc<LobbyEvent, LobbyState> {

  LobbyBloc(this._repository, this._secureStorage)
      : super(const LobbyInitial()) {
    on<LoadRoomsEvent>(_onLoadRooms);
    on<CreateRoomEvent>(_onCreateRoom);
    on<LoadRoomEvent>(_onLoadRoom);
    on<RefreshRoomEvent>(_onRefreshRoom);
    on<JoinRoomEvent>(_onJoinRoom);
    on<ApprovePlayerEvent>(_onApprovePlayer);
    on<DeclinePlayerEvent>(_onDeclinePlayer);
    on<ToggleReadyEvent>(_onToggleReady);
    on<StartGameEvent>(_onStartGame);
    on<ClearLobbyErrorEvent>(_onClearError);
  }
  final LobbyRepository _repository;
  final SecureStorage _secureStorage;

  Future<void> _onLoadRooms(
    LoadRoomsEvent event,
    Emitter<LobbyState> emit,
  ) async {
    emit(const LobbyLoading());
    try {
      final rooms = await _repository.listRooms(status: event.status);
      emit(LobbyLoaded(rooms: rooms));
    } catch (e) {
      emit(LobbyError(message: e.toString()));
    }
  }

  Future<void> _onCreateRoom(
    CreateRoomEvent event,
    Emitter<LobbyState> emit,
  ) async {
    emit(const LobbyCreating());
    try {
      final room = await _repository.createRoom(
        name: event.name,
        scenarioVersionId: event.scenarioVersionId,
        maxPlayers: event.maxPlayers,
        characterId: event.characterId,
      );
      final isHost = await _isCurrentUserHost(room);
      emit(LobbyRoomDetail(room: room, isCurrentUserHost: isHost));
    } catch (e) {
      emit(LobbyError(
        message: 'Не удалось создать комнату: $e',
      ),);
    }
  }

  Future<void> _onLoadRoom(
    LoadRoomEvent event,
    Emitter<LobbyState> emit,
  ) async {
    emit(const LobbyLoading());
    try {
      final room = await _repository.getRoom(event.roomId);
      final isHost = await _isCurrentUserHost(room);
      emit(LobbyRoomDetail(room: room, isCurrentUserHost: isHost));
    } catch (e) {
      emit(LobbyError(
        message: 'Не удалось загрузить комнату: $e',
      ),);
    }
  }

  Future<void> _onRefreshRoom(
    RefreshRoomEvent event,
    Emitter<LobbyState> emit,
  ) async {
    try {
      final room = await _repository.getRoom(event.roomId);
      final isHost = await _isCurrentUserHost(room);
      emit(LobbyRoomDetail(room: room, isCurrentUserHost: isHost));
    } catch (e) {
      emit(LobbyError(
        message: 'Не удалось обновить комнату: $e',
      ),);
    }
  }

  Future<void> _onJoinRoom(
    JoinRoomEvent event,
    Emitter<LobbyState> emit,
  ) async {
    emit(const LobbyLoading());
    try {
      await _repository.joinRoom(event.roomId);
      final room = await _repository.getRoom(event.roomId);
      final isHost = await _isCurrentUserHost(room);
      emit(LobbyRoomDetail(room: room, isCurrentUserHost: isHost));
    } catch (e) {
      emit(LobbyError(
        message: 'Не удалось присоединиться: $e',
      ),);
    }
  }

  Future<void> _onApprovePlayer(
    ApprovePlayerEvent event,
    Emitter<LobbyState> emit,
  ) async {
    try {
      await _repository.approvePlayer(event.roomId, event.playerId);
      final room = await _repository.getRoom(event.roomId);
      final isHost = await _isCurrentUserHost(room);
      emit(LobbyRoomDetail(room: room, isCurrentUserHost: isHost));
    } catch (e) {
      emit(LobbyError(
        message: 'Не удалось одобрить игрока: $e',
      ),);
    }
  }

  Future<void> _onDeclinePlayer(
    DeclinePlayerEvent event,
    Emitter<LobbyState> emit,
  ) async {
    try {
      await _repository.declinePlayer(event.roomId, event.playerId);
      final room = await _repository.getRoom(event.roomId);
      final isHost = await _isCurrentUserHost(room);
      emit(LobbyRoomDetail(room: room, isCurrentUserHost: isHost));
    } catch (e) {
      emit(LobbyError(
        message: 'Не удалось отклонить игрока: $e',
      ),);
    }
  }

  Future<void> _onToggleReady(
    ToggleReadyEvent event,
    Emitter<LobbyState> emit,
  ) async {
    try {
      await _repository.toggleReady(
        roomId: event.roomId,
        characterId: event.characterId,
        ready: event.ready,
      );
      final room = await _repository.getRoom(event.roomId);
      final isHost = await _isCurrentUserHost(room);
      emit(LobbyRoomDetail(room: room, isCurrentUserHost: isHost));
    } catch (e) {
      emit(LobbyError(
        message: 'Не удалось обновить готовность: $e',
      ),);
    }
  }

  Future<void> _onStartGame(
    StartGameEvent event,
    Emitter<LobbyState> emit,
  ) async {
    try {
      final session = await _repository.startGame(event.roomId);
      final room = await _repository.getRoom(event.roomId);
      emit(LobbyGameStarting(room: room, session: session));
    } catch (e) {
      emit(LobbyError(
        message: 'Не удалось начать игру: $e',
      ),);
    }
  }

  Future<void> _onClearError(
    ClearLobbyErrorEvent event,
    Emitter<LobbyState> emit,
  ) async {
    emit(const LobbyInitial());
  }

  Future<bool> _isCurrentUserHost(Room room) async {
    final userId = await _secureStorage.getUserId();
    if (userId == null) return false;
    return room.host?.userId == userId;
  }
}
