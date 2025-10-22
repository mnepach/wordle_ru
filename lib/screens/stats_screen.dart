import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../constants/colors.dart';
import '../models/game_stats.dart';
import '../services/stats_service.dart';
import '../services/sync_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({Key? key}) : super(key: key);

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> with TickerProviderStateMixin {
  late Future<GameStats> _statsFuture;
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;
  late AnimationController _syncIconController;

  SyncStatus _syncStatus = SyncStatus.idle;

  @override
  void initState() {
    super.initState();
    _statsFuture = StatsService.loadStats();

    _floatController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -5, end: 5).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _syncIconController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Подписываемся на статус синхронизации
    SyncService().syncStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _syncStatus = status;
          if (status == SyncStatus.syncing) {
            _syncIconController.repeat();
          } else {
            _syncIconController.stop();
            _syncIconController.value = 0;
          }
          if (status == SyncStatus.synced) {
            _refreshStats();
          }
        });
      }
    });

    _syncStatus = SyncService().currentStatus;
  }

  @override
  void dispose() {
    _floatController.dispose();
    _syncIconController.dispose();
    super.dispose();
  }

  void _refreshStats() {
    setState(() {
      _statsFuture = StatsService.loadStats();
    });
  }

  Future<void> _forceSync() async {
    try {
      await SyncService().forceSync();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Синхронизация завершена! ✨'),
            backgroundColor: AppColors.correct,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка синхронизации: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showSyncInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: const Row(
          children: [
            Icon(Icons.cloud, color: AppColors.primary),
            SizedBox(width: 8),
            Text(
              'Облачная синхронизация',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ваша статистика автоматически синхронизируется между всеми устройствами через облако.',
              style: TextStyle(color: AppColors.text, height: 1.5),
            ),
            const SizedBox(height: 16),
            _buildSyncInfoRow('Статус:', SyncService().getSyncInfo()),
            FutureBuilder<String?>(
              future: SyncService().getUserId(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return _buildSyncInfoRow(
                    'ID аккаунта:',
                    snapshot.data!.substring(0, 12) + '...',
                  );
                }
                return const SizedBox();
              },
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.keyboardDefault,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Синхронизация происходит автоматически каждые 30 секунд',
                      style: TextStyle(fontSize: 12, color: AppColors.text),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть', style: TextStyle(color: AppColors.text)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _forceSync();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
            label: const Text('Синхронизировать', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.text.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: const Text(
          'Сбросить статистику? (・_・;)',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text),
        ),
        content: const Text(
          'Вся статистика будет безвозвратно удалена на всех устройствах!',
          style: TextStyle(color: AppColors.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена', style: TextStyle(color: AppColors.text)),
          ),
          ElevatedButton(
            onPressed: () async {
              await StatsService.resetStats();
              if (mounted) {
                Navigator.pop(context);
                _refreshStats();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Статистика сброшена'),
                    backgroundColor: AppColors.absent,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            child: const Text('Сбросить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.gradientStart, AppColors.gradientEnd],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: FutureBuilder<GameStats>(
                  future: _statsFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      );
                    }

                    final stats = snapshot.data!;
                    return RefreshIndicator(
                      onRefresh: () async {
                        await _forceSync();
                      },
                      color: AppColors.primary,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            _buildSyncStatusCard(),
                            const SizedBox(height: 16),
                            _buildStatsCards(stats),
                            const SizedBox(height: 24),
                            _buildGuessDistribution(stats),
                            const SizedBox(height: 24),
                            _buildDeviceInfo(stats),
                            const SizedBox(height: 24),
                            _buildResetButton(),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.text),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'Статистика (◕‿◕)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: AppColors.text,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildSyncStatusCard() {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (_syncStatus) {
      case SyncStatus.syncing:
        statusColor = AppColors.primary;
        statusIcon = Icons.sync;
        statusText = 'Синхронизация...';
        break;
      case SyncStatus.synced:
        statusColor = AppColors.correct;
        statusIcon = Icons.cloud_done;
        statusText = SyncService().getSyncInfo();
        break;
      case SyncStatus.error:
        statusColor = Colors.orange;
        statusIcon = Icons.cloud_off;
        statusText = 'Ошибка синхронизации';
        break;
      case SyncStatus.offline:
        statusColor = AppColors.absent;
        statusIcon = Icons.cloud_off;
        statusText = 'Оффлайн режим';
        break;
      default:
        statusColor = AppColors.keyboardText;
        statusIcon = Icons.cloud_queue;
        statusText = 'Ожидание синхронизации';
    }

    return GestureDetector(
      onTap: _showSyncInfo,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            RotationTransition(
              turns: _syncIconController,
              child: Icon(statusIcon, color: statusColor, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Облачная синхронизация',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.text.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.info_outline, color: AppColors.primary.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards(GameStats stats) {
    return Row(
      children: [
        Expanded(child: _buildStatCard('Игр', stats.gamesPlayed.toString(), Icons.gamepad)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Побед', '${stats.winRate.toStringAsFixed(0)}%', Icons.emoji_events)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Серия', stats.currentStreak.toString(), Icons.local_fire_department)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Макс', stats.maxStreak.toString(), Icons.star)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return AnimatedBuilder(
      animation: _floatAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnimation.value),
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.text.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuessDistribution(GameStats stats) {
    final maxCount = stats.guessDistribution.values.fold(0, math.max);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Распределение побед',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(6, (index) {
            final attempts = index + 1;
            final count = stats.guessDistribution[attempts] ?? 0;
            final percentage = maxCount > 0 ? count / maxCount : 0.0;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    child: Text(
                      '$attempts',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.keyboardDefault,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          height: 32,
                          width: MediaQuery.of(context).size.width * 0.6 * percentage,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.secondary],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              count > 0 ? count.toString() : '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDeviceInfo(GameStats stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.devices, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Информация об устройстве',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Платформа:', StatsService.getPlatformInfo()),
          _buildInfoRow('ID устройства:', stats.deviceId),
          FutureBuilder<String?>(
            future: SyncService().getUserId(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return _buildInfoRow(
                  'Облачный ID:',
                  '${snapshot.data!.substring(0, 8)}...',
                );
              }
              return const SizedBox();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.text.withOpacity(0.7),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _showResetConfirmation,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: const BorderSide(color: Colors.red, width: 2),
        ),
        icon: const Icon(Icons.delete_outline, color: Colors.red),
        label: const Text(
          'Сбросить статистику',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
      ),
    );
  }
}