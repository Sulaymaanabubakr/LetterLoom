import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/multiplayer_game.dart';
import '../../models/game_state.dart';
import '../../theme/app_theme.dart';
import '../../core/toast_utils.dart';
import '../game/game_notifier.dart';
import '../game/game_screen.dart';
import 'multiplayer_game_notifier.dart';
import 'multiplayer_repository.dart';

class MultiplayerLobbyScreen extends StatefulWidget {
  const MultiplayerLobbyScreen({super.key});

  @override
  State<MultiplayerLobbyScreen> createState() => _MultiplayerLobbyScreenState();
}

class _MultiplayerLobbyScreenState extends State<MultiplayerLobbyScreen> {
  final _nameController = TextEditingController();
  final _roomController = TextEditingController();
  final _repository = MultiplayerRepository();
  StreamSubscription<MultiplayerGame?>? _gameSubscription;
  MultiplayerGame? _game;
  bool _isBusy = false;
  bool _isLoadingRooms = true;
  bool _showJoin = false;
  String? _error;
  List<MultiplayerGame> _myGames = const [];
  bool _isRoomOwner = false;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roomController.dispose();
    _gameSubscription?.cancel();
    super.dispose();
  }

  Future<void> _createGame() async {
    await _runAction(() async {
      final game = await _repository.createGame(_nameController.text);
      await _loadRooms(showErrors: false);
      _showGame(game, isOwner: true);
    });
  }

  Future<void> _joinGame() async {
    await _runAction(() async {
      final game = await _repository.joinGame(
        _roomController.text,
        _nameController.text,
      );
      await _loadRooms(showErrors: false);
      _showGame(game, isOwner: false);
    });
  }

  Future<void> _loadRooms({bool showErrors = true}) async {
    if (mounted) setState(() => _isLoadingRooms = true);
    try {
      final rooms = await _repository.loadRooms();
      if (mounted) {
        setState(() {
          _myGames = rooms.myGames;
          _isLoadingRooms = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoadingRooms = false;
          if (showErrors) _error = error.toString();
        });
      }
    }
  }

  Future<void> _runAction(Future<void> Function() action) async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _showGame(MultiplayerGame game, {bool? isOwner}) {
    _gameSubscription?.cancel();
    _gameSubscription = _repository.watchGame(game.id).listen((updated) {
      if (!mounted) return;
      if (updated == null) {
        _gameSubscription?.cancel();
        setState(() => _game = null);
        ToastUtils.show(context, 'Room deleted');
        _loadRooms(showErrors: false);
        return;
      }
      setState(() => _game = updated.copyWith(isOwner: _isRoomOwner));
    });
    setState(() {
      _isRoomOwner = isOwner ?? game.isOwner;
      _game = game.copyWith(isOwner: _isRoomOwner);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PremiumBackground(
        child: SafeArea(
          child: RefreshIndicator(
            color: AppTheme.shinyGold,
            onRefresh: _loadRooms,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 18),
                  _ornamentalDivider(),
                  const SizedBox(height: 20),
                  if (_game == null) ...[
                    _buildRoomsOverview(),
                    const SizedBox(height: 16),
                    _buildEntryCard(),
                  ] else
                    _buildRoomCard(_game!),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF010E0A),
                border: Border.all(
                  color: AppTheme.shinyGold.withValues(alpha: 0.55),
                ),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: AppTheme.shinyGold,
                size: 19,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('➔  ', style: _ornamentStyle()),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Color(0xFFFFF1CC),
                  Color(0xFFD4AF37),
                  Color(0xFF8A640F),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ).createShader(bounds),
              child: Text(
                'Play Online',
                style: GoogleFonts.lora(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            Text('  ➔', style: _ornamentStyle()),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          'A word match across the distance',
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: AppTheme.mutedIvory,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }

  TextStyle _ornamentStyle() => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.bold,
    color: AppTheme.shinyGold,
  );

  Widget _ornamentalDivider() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppTheme.shinyGold.withValues(alpha: 0.45),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Transform.rotate(
          angle: 3.14159 / 4,
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: AppTheme.emeraldGreen,
              border: Border.all(color: AppTheme.shinyGold, width: 1.3),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.shinyGold.withValues(alpha: 0.45),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEntryCard() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Choose your table',
            textAlign: TextAlign.center,
            style: GoogleFonts.lora(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: AppTheme.ivoryText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Create a private room for a friend, or join one with a room code.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.mutedIvory,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),
          _field(_nameController, 'Display name', Icons.person_outline_rounded),
          const SizedBox(height: 16),
          if (_showJoin) ...[
            _field(
              _roomController,
              'Six-character room code',
              Icons.vpn_key_outlined,
              uppercase: true,
            ),
            const SizedBox(height: 16),
            _goldButton(
              'Join Room',
              Icons.login_rounded,
              _isBusy ? null : _joinGame,
            ),
            const SizedBox(height: 12),
            _textButton(
              'Create a new room instead',
              () => setState(() => _showJoin = false),
            ),
          ] else ...[
            _goldButton(
              'Create Room',
              Icons.add_circle_outline_rounded,
              _isBusy ? null : _createGame,
            ),
            const SizedBox(height: 12),
            _textButton(
              'I have a room code',
              () => setState(() => _showJoin = true),
            ),
          ],
          if (_isBusy) ...[
            const SizedBox(height: 18),
            const Center(
              child: CircularProgressIndicator(
                color: AppTheme.shinyGold,
                strokeWidth: 2,
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            _errorBanner(_error!),
          ],
        ],
      ),
    );
  }

  Widget _buildRoomsOverview() {
    if (_isLoadingRooms) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: CircularProgressIndicator(
            color: AppTheme.shinyGold,
            strokeWidth: 2,
          ),
        ),
      );
    }
    if (_myGames.isEmpty) {
      return const SizedBox.shrink();
    }

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Your online tables',
            textAlign: TextAlign.center,
            style: GoogleFonts.lora(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.ivoryText,
            ),
          ),
          if (_myGames.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._myGames.map((game) => _roomListTile(game, mine: true)),
          ],
          const SizedBox(height: 6),
          _textButton('Refresh rooms', () => _loadRooms()),
        ],
      ),
    );
  }

  Widget _roomListTile(MultiplayerGame game, {bool mine = false}) {
    final statusLabel = game.status == 'active'
        ? 'Match started'
        : 'Waiting for player';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.scaffoldDark.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.shinyGold.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.table_restaurant_rounded,
            color: AppTheme.shinyGold,
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  game.roomCode,
                  style: GoogleFonts.inter(
                    color: AppTheme.ivoryText,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  mine ? statusLabel : 'Open room',
                  style: GoogleFonts.inter(
                    color: AppTheme.mutedIvory,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: mine
                ? () => _showGame(game, isOwner: game.isOwner)
                : () {
                    _roomController.text = game.roomCode;
                    setState(() => _showJoin = true);
                  },
            child: Text(
              mine ? 'Open' : 'Join',
              style: GoogleFonts.inter(
                color: AppTheme.shinyGold,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(MultiplayerGame game) {
    final isActive = game.status == 'active';
    final isStopped = game.status == 'abandoned';
    return _panel(
      child: Column(
        children: [
          Icon(
            isActive ? Icons.groups_rounded : Icons.hourglass_top_rounded,
            color: AppTheme.shinyGold,
            size: 42,
          ),
          const SizedBox(height: 12),
          Text(
            isStopped
                ? 'Room stopped'
                : isActive
                ? 'Your opponent has joined'
                : 'Room ready',
            style: GoogleFonts.lora(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: AppTheme.ivoryText,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            isStopped
                ? 'This room is no longer available.'
                : isActive
                ? 'The table is ready.'
                : 'Share this code with the person you want to play.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.mutedIvory,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.scaffoldDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.shinyGold.withValues(alpha: 0.65),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SelectableText(
                  game.roomCode,
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 5,
                    color: AppTheme.shinyGold,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: game.roomCode));
                    ToastUtils.show(context, 'Room code copied');
                  },
                  icon: const Icon(
                    Icons.copy_rounded,
                    color: AppTheme.mutedIvory,
                  ),
                  tooltip: 'Copy room code',
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          if (!isActive && !isStopped)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 8,
                  height: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppTheme.shinyGold,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Waiting for your opponent…',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.mutedIvory,
                  ),
                ),
              ],
            ),
          if (isActive)
            _goldButton(
              'Open Board',
              Icons.grid_on_rounded,
              _isBusy ? null : () => _openBoard(game),
            ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isRoomOwner && !isStopped) ...[
                _roomActionButton(
                  icon: Icons.stop_circle_outlined,
                  label: 'Stop room',
                  onPressed: _isBusy ? null : () => _manageRoom(game, 'stop'),
                ),
                const SizedBox(width: 10),
              ],
              if (_isRoomOwner && !isActive) ...[
                _roomActionButton(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete room',
                  onPressed: _isBusy ? null : () => _manageRoom(game, 'delete'),
                  danger: true,
                ),
                const SizedBox(width: 10),
              ],
              if (!_isRoomOwner && !isStopped) ...[
                _roomActionButton(
                  icon: Icons.logout_rounded,
                  label: 'Leave room',
                  onPressed: _isBusy ? null : () => _manageRoom(game, 'leave'),
                ),
                const SizedBox(width: 10),
              ],
              _roomActionButton(
                icon: Icons.arrow_back_rounded,
                label: 'Back to rooms',
                onPressed: () {
                  _gameSubscription?.cancel();
                  setState(() => _game = null);
                  _loadRooms();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _manageRoom(MultiplayerGame game, String action) async {
    final verb = action == 'delete'
        ? 'delete'
        : action == 'leave'
        ? 'leave'
        : 'stop';
    final confirmed = await _showPremiumConfirmation(
      title: '$verb room?',
      message: action == 'delete'
          ? 'This will permanently remove room ${game.roomCode}.'
          : action == 'leave'
          ? 'You will leave room ${game.roomCode}.'
          : 'Players will no longer be able to continue this room.',
      confirmLabel: verb,
    );
    if (confirmed != true) return;
    await _runAction(() async {
      final updated = await _repository.manageRoom(game.id, action);
      _gameSubscription?.cancel();
      if (mounted) {
        setState(() => _game = updated);
        await _loadRooms(showErrors: false);
        if (!mounted) return;
        if (action == 'delete' || action == 'leave') {
          setState(() => _game = null);
          ToastUtils.show(
            context,
            action == 'delete' ? 'Room deleted' : 'You left the room',
          );
        } else {
          ToastUtils.show(context, 'Room stopped');
        }
      }
    });
  }

  Future<void> _openBoard(MultiplayerGame room) async {
    await _runAction(() async {
      if (room.status != 'active') {
        if (mounted) {
          ToastUtils.show(context, 'Waiting for the second player to join.');
        }
        return;
      }
      final seed = GameNotifier();
      seed.startNewGame('easy', persist: false);
      var snapshot = await _repository.loadGameState(room.id);
      if (snapshot.players.length < 2) {
        if (mounted) {
          ToastUtils.show(context, 'Waiting for the second player to join.');
        }
        return;
      }
      if (snapshot.game.board.isEmpty) {
        if (!_isRoomOwner) {
          if (mounted) {
            ToastUtils.show(
              context,
              'The room owner needs to open the board first.',
            );
          }
          return;
        }
        snapshot = await _repository.initializeGameState(
          room.id,
          seed.currentState,
        );
      }
      final opponent = snapshot.players
          .whereType<Map>()
          .map((player) => Map<String, dynamic>.from(player))
          .firstWhere(
            (player) =>
                player['user_id'] !=
                Supabase.instance.client.auth.currentUser?.id,
            orElse: () => <String, dynamic>{'user_id': room.createdByUserId},
          );
      final opponentName = opponent['display_name'] as String?;
      final state = snapshot.hydrate(seed.currentState);
      Future<void> restartMatch() async {
        final restartSeed = GameNotifier();
        restartSeed.startNewGame('easy', persist: false);
        await _repository.restartGameState(room.id, restartSeed.currentState);
      }

      Future<void> leaveMatch() async {
        await _repository.manageRoom(room.id, 'leave');
        if (mounted) {
          Navigator.of(context).pop();
          ToastUtils.show(context, 'You left the match');
        }
      }

      Future<void> endMatch() async {
        await _repository.manageRoom(room.id, 'stop');
        if (mounted) {
          Navigator.of(context).pop();
          ToastUtils.show(context, 'Match ended');
        }
      }

      final provider =
          StateNotifierProvider<MultiplayerGameNotifier, GameState>(
            (ref) => MultiplayerGameNotifier(
              gameId: room.id,
              opponentUserId: opponent['user_id'] as String? ?? '',
              initialState: state,
              repository: _repository,
            ),
          );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProviderScope(
            overrides: [
              provider.overrideWith(
                (ref) => MultiplayerGameNotifier(
                  gameId: room.id,
                  opponentUserId: opponent['user_id'] as String? ?? '',
                  initialState: state,
                  repository: _repository,
                ),
              ),
            ],
            child: GameScreen(
              controllerProvider: provider,
              isMultiplayer: true,
              opponentName: opponentName,
              onMultiplayerRestart: _isRoomOwner ? restartMatch : null,
              onMultiplayerEnd: _isRoomOwner ? endMatch : null,
              onMultiplayerLeave: _isRoomOwner ? null : leaveMatch,
            ),
          ),
        ),
      );
    });
  }

  Widget _roomActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool danger = false,
  }) {
    return Tooltip(
      message: label,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        color: danger ? const Color(0xFFE0524B) : AppTheme.shinyGold,
        iconSize: 25,
        style: IconButton.styleFrom(
          backgroundColor: AppTheme.scaffoldDark,
          side: BorderSide(
            color: (danger ? const Color(0xFFE0524B) : AppTheme.shinyGold)
                .withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  Future<bool> _showPremiumConfirmation({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppTheme.darkGreenGradient,
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.shinyGold, width: 1.3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('➔  ', style: _ornamentStyle()),
                      Text(
                        title.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.lora(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.shinyGold,
                        ),
                      ),
                      Text('  ➔', style: _ornamentStyle()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: AppTheme.mutedIvory,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _modalButton(
                          'Cancel',
                          () => Navigator.pop(context, false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _modalButton(
                          confirmLabel,
                          () => Navigator.pop(context, true),
                          primary: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ) ??
        false;
  }

  Widget _modalButton(
    String label,
    VoidCallback onTap, {
    bool primary = false,
  }) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: primary
            ? const LinearGradient(colors: AppTheme.goldGradient)
            : const LinearGradient(colors: AppTheme.darkGreenGradient),
        border: primary
            ? null
            : Border.all(color: AppTheme.shinyGold.withValues(alpha: 0.55)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Text(
              label.toUpperCase(),
              style: GoogleFonts.lora(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: primary ? const Color(0xFF1E1402) : AppTheme.shinyGold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _panel({required Widget child}) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: AppTheme.darkGreenGradient,
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppTheme.shinyGold.withValues(alpha: 0.35)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: child,
  );

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool uppercase = false,
  }) {
    return TextField(
      controller: controller,
      textCapitalization: uppercase
          ? TextCapitalization.characters
          : TextCapitalization.words,
      autocorrect: false,
      style: GoogleFonts.inter(color: AppTheme.ivoryText, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        floatingLabelAlignment: FloatingLabelAlignment.center,
        prefixIcon: Icon(icon, color: AppTheme.shinyGold),
        filled: true,
        fillColor: AppTheme.scaffoldDark.withValues(alpha: 0.7),
        labelStyle: GoogleFonts.inter(color: AppTheme.mutedIvory),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppTheme.lightGrey.withValues(alpha: 0.8),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.shinyGold, width: 1.4),
        ),
      ),
    );
  }

  Widget _goldButton(String label, IconData icon, VoidCallback? onPressed) {
    return SizedBox(
      height: 54,
      child: Opacity(
        opacity: onPressed == null ? 0.45 : 1,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: AppTheme.goldGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.shinyGold.withValues(alpha: 0.28),
                offset: const Offset(0, 5),
                blurRadius: 12,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: const Color(0xFF1E1402)),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF1E1402),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _textButton(String label, VoidCallback onPressed) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: AppTheme.shinyGold,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF4C100C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0524B)),
      ),
      child: Text(
        message,
        style: GoogleFonts.inter(color: AppTheme.ivoryText, fontSize: 13),
      ),
    );
  }
}
