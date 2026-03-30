import 'package:flutter/material.dart';
import 'package:apsl_wallpaper_scheduler/apsl_wallpaper_scheduler.dart';
import 'package:flutter/services.dart';

double lat = 21.2319998,
    lng = 72.8211632,
    deviceWidth = 1080.0,
    deviceHeight = 2400.0;

List<String> urlLinks = [
  "https://tools.shubhpanchang.com/api/live-wallpaper?type=choghadiya&locale=en&latitude=$lat&longitude=$lng&width=$deviceWidth&height=$deviceHeight",
  "https://tools.shubhpanchang.com/api/live-wallpaper?type=choghadiya&locale=gu&latitude=$lat&longitude=$lng&width=$deviceWidth&height=$deviceHeight",
  "https://tools.shubhpanchang.com/api/live-wallpaper?type=choghadiya&locale=mr&latitude=$lat&longitude=$lng&width=$deviceWidth&height=$deviceHeight",
  "https://tools.shubhpanchang.com/api/live-wallpaper?type=choghadiya&locale=hi&latitude=$lat&longitude=$lng&width=$deviceWidth&height=$deviceHeight",
  "https://tools.shubhpanchang.com/api/live-wallpaper?type=choghadiya&locale=en&latitude=$lat&longitude=$lng&width=$deviceWidth&height=$deviceHeight&screen=2",
  "https://tools.shubhpanchang.com/api/live-wallpaper?type=choghadiya&locale=gu&latitude=$lat&longitude=$lng&width=$deviceWidth&height=$deviceHeight&screen=2",
  "https://tools.shubhpanchang.com/api/live-wallpaper?type=choghadiya&locale=mr&latitude=$lat&longitude=$lng&width=$deviceWidth&height=$deviceHeight&screen=2",
  "https://tools.shubhpanchang.com/api/live-wallpaper?type=choghadiya&locale=hi&latitude=$lat&longitude=$lng&width=$deviceWidth&height=$deviceHeight&screen=2",
  "https://tools.shubhpanchang.com/api/live-wallpaper?locale=en&latitude=$lat&longitude=$lng&width=$deviceWidth&height=$deviceHeight&screen=3&background=1&center=false",
  "https://tools.shubhpanchang.com/api/live-wallpaper?locale=hi&latitude=$lat&longitude=$lng&width=$deviceWidth&height=$deviceHeight&screen=3&background=2&center=false",
  "https://tools.shubhpanchang.com/api/live-wallpaper?locale=gu&latitude=$lat&longitude=$lng&width=$deviceWidth&height=$deviceHeight&screen=3&background=3&center=false",
  "https://tools.shubhpanchang.com/api/live-wallpaper?locale=mr&latitude=$lat&longitude=$lng&width=$deviceWidth&height=$deviceHeight&screen=3&background=4&center=false",
  "https://tools.shubhpanchang.com/api/live-wallpaper?locale=en&latitude=$lat&longitude=$lng&width=$deviceWidth&height=$deviceHeight&screen=3&background=5&center=false",
];

// List<String> urlLinks = [
//   "https://tools.shubhpanchang.com/api/live-wallpaper?type=choghadiya&locale=en&latitude=21.2319998&longitude=72.8211632&width=1080.0&height=2400.0",
//   "https://tools.shubhpanchang.com/api/live-wallpaper?type=choghadiya&locale=gu&latitude=21.2319998&longitude=72.8211632&width=1080.0&height=2400.0",
//   "https://tools.shubhpanchang.com/api/live-wallpaper?type=choghadiya&locale=mr&latitude=21.2319998&longitude=72.8211632&width=1080.0&height=2400.0",
//   "https://tools.shubhpanchang.com/api/live-wallpaper?type=choghadiya&locale=hi&latitude=21.2319998&longitude=72.8211632&width=1080.0&height=2400.0",
//   "https://tools.shubhpanchang.com/api/live-wallpaper?type=choghadiya&locale=en&latitude=21.2319998&longitude=72.8211632&width=1080.0&height=2400.0&screen=2",
//   "https://tools.shubhpanchang.com/api/live-wallpaper?type=choghadiya&locale=gu&latitude=21.2319998&longitude=72.8211632&width=1080.0&height=2400.0&screen=2",
//   "https://tools.shubhpanchang.com/api/live-wallpaper?type=choghadiya&locale=mr&latitude=21.2319998&longitude=72.8211632&width=1080.0&height=2400.0&screen=2",
//   "https://tools.shubhpanchang.com/api/live-wallpaper?type=choghadiya&locale=hi&latitude=21.2319998&longitude=72.8211632&width=1080.0&height=2400.0&screen=2",
//   "https://tools.shubhpanchang.com/api/live-wallpaper?locale=en&latitude=21.2319998&longitude=72.8211632&width=1080.0&height=2400.0&screen=3&background=1&center=false",
//   "https://tools.shubhpanchang.com/api/live-wallpaper?locale=hi&latitude=21.2319998&longitude=72.8211632&width=1080.0&height=2400.0&screen=3&background=2&center=false",
//   "https://tools.shubhpanchang.com/api/live-wallpaper?locale=gu&latitude=21.2319998&longitude=72.8211632&width=1080.0&height=2400.0&screen=3&background=3&center=false",
//   "https://tools.shubhpanchang.com/api/live-wallpaper?locale=mr&latitude=21.2319998&longitude=72.8211632&width=1080.0&height=2400.0&screen=3&background=4&center=false",
//   "https://tools.shubhpanchang.com/api/live-wallpaper?locale=en&latitude=21.2319998&longitude=72.8211632&width=1080.0&height=2400.0&screen=3&background=5&center=false",
// ];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Step 1: Initialize the package ──────────────────────────────────────
  await ApslWallpaperScheduler.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wallpaper Scheduler Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SchedulerDemoScreen(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Demo screen — shows all package operations
// ─────────────────────────────────────────────────────────────────────────────

// "choghadiya":
//     "https://tools.shubhpanchang.com/api/live-wallpaper?type=choghadiya&locale=$language&latitude=$lat&longitude=$lng&width=$deviceWidth&height=$deviceHeight",
// "gowri":
//     "https://tools.shubhpanchang.com/api/live-wallpaper?type=gowri&locale=$language&latitude=$lat&longitude=$lng&width=$deviceWidth&height=$deviceHeight",
// "hora":
//     "https://tools.shubhpanchang.com/api/live-wallpaper?type=hora&locale=$language&latitude=$lat&longitude=$lng&width=$deviceWidth&height=$deviceHeight",
// "choghadiya_clock":
//     "https://tools.shubhpanchang.com/api/live-wallpaper?type=choghadiya&locale=$language&latitude=$lat&longitude=$lng&width=$deviceWidth&height=$deviceHeight&screen=2",
// "gowri_clock":
//     "https://tools.shubhpanchang.com/api/live-wallpaper?type=gowri&locale=$language&latitude=$lat&longitude=$lng&width=$deviceWidth&height=$deviceHeight&screen=2",
// "hora_clock":
//     "https://tools.shubhpanchang.com/api/live-wallpaper?type=hora&locale=$language&latitude=$lat&longitude=$lng&width=$deviceWidth&height=$deviceHeight&screen=2",
// "quotes":
//     "https://tools.shubhpanchang.com/api/live-wallpaper?locale=$originalLanguage&latitude=$lat&longitude=$lng&width=$deviceWidth&height=$deviceHeight&screen=3&background=$backgroundId"

class SchedulerDemoScreen extends StatefulWidget {
  const SchedulerDemoScreen({super.key});

  @override
  State<SchedulerDemoScreen> createState() => _SchedulerDemoScreenState();
}

class _SchedulerDemoScreenState extends State<SchedulerDemoScreen>
    with WidgetsBindingObserver {
  List<WallpaperSchedule> _schedules = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSchedules();
    _requestPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadSchedules();
  }

  // ── Step 2: Request permissions early (best practice) ───────────────────
  Future<void> _requestPermissions() async {
    await ApslWallpaperScheduler.requestExactAlarmPermission();
    await ApslWallpaperScheduler.requestBatteryOptimizationExemption();
  }

  // ── Step 3: Load all schedules ──────────────────────────────────────────
  Future<void> _loadSchedules() async {
    final schedules = await ApslWallpaperScheduler.getAllSchedules();
    if (mounted)
      setState(() {
        _schedules = schedules;
        _loading = false;
      });
  }

  // ── Step 4: Create a schedule ───────────────────────────────────────────
  Future<void> _showCreateDialog() async {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    TimeOfDay time = const TimeOfDay(hour: 8, minute: 0);
    WallpaperTarget target = WallpaperTarget.both;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('New Schedule'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(labelText: 'Image URL'),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Time: ${_fmt(time)}'),
                  trailing: const Icon(Icons.schedule),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: ctx,
                      initialTime: time,
                    );
                    if (picked != null) setDlgState(() => time = picked);
                  },
                ),
                DropdownButton<WallpaperTarget>(
                  value: target,
                  items: WallpaperTarget.values
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.label),
                          ))
                      .toList(),
                  onChanged: (v) => setDlgState(() => target = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                // ── createSchedule ───────────────────────────────────────
                final result = await ApslWallpaperScheduler.createSchedule(
                  WallpaperScheduleConfig(
                    name: nameCtrl.text.trim().isEmpty
                        ? 'My Schedule'
                        : nameCtrl.text.trim(),
                    imageUrl: urlCtrl.text.trim(),
                    time: time,
                    target: target,
                    activate: true,
                  ),
                );
                if (result.isSuccess) {
                  _snack('Created: ${result.schedule!.name}', green: true);
                } else {
                  _snack('Error: ${result.error}', red: true);
                }
                await _loadSchedules();
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 5: Stop a schedule ─────────────────────────────────────────────
  Future<void> _stop(WallpaperSchedule s) async {
    await ApslWallpaperScheduler.stopSchedule(s.id);
    await _loadSchedules();
    _snack('"${s.name}" stopped.');
  }

  // ── Step 6: Start a stopped schedule ────────────────────────────────────
  Future<void> _start(WallpaperSchedule s) async {
    final result = await ApslWallpaperScheduler.startSchedule(s.id);
    await _loadSchedules();
    if (result.isSuccess) {
      _snack('"${s.name}" started.', green: true);
    } else {
      _snack('Error: ${result.error}', red: true);
    }
  }

  // ── Step 7: Delete a schedule ────────────────────────────────────────────
  Future<void> _delete(WallpaperSchedule s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Schedule'),
        content: Text('Delete "${s.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    await ApslWallpaperScheduler.deleteSchedule(s.id);
    await _loadSchedules();
    _snack('"${s.name}" deleted.');
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _fmt(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }

  void _snack(String msg, {bool green = false, bool red = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: green
          ? Colors.green
          : red
              ? Colors.red
              : null,
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallpaper Scheduler Demo'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSchedules,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 200,
            child: ListView.separated(
                separatorBuilder: (context, index) => Divider(),
                itemCount: urlLinks.length,
                itemBuilder: (context, index) => Row(
                      children: [
                        Expanded(
                          child: Text(
                            urlLinks[index],
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            await Clipboard.setData(
                                ClipboardData(text: urlLinks[index]));
                          },
                          icon: Icon(Icons.copy),
                        )
                      ],
                    )),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _schedules.isEmpty
                    ? const Center(
                        child: Text(
                          'No schedules yet.\nTap + to create one.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _schedules.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _buildTile(_schedules[i]),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTile(WallpaperSchedule s) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: s.isActive ? Colors.green : Colors.grey,
          child: Icon(
            s.isActive ? Icons.alarm_on : Icons.alarm_off,
            color: Colors.white,
            size: 20,
          ),
        ),
        title:
            Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${s.formattedTime} • ${s.targetLabel}\n'
          '${s.lastUpdated != null ? "Updated: ${s.lastUpdated}" : "Never updated"}\n'
          '${s.lastError != null ? "Error: ${s.lastError}" : "Success"}',
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'start') _start(s);
            if (v == 'stop') _stop(s);
            if (v == 'delete') _delete(s);
          },
          itemBuilder: (_) => [
            if (!s.isActive)
              const PopupMenuItem(value: 'start', child: Text('Start')),
            if (s.isActive)
              const PopupMenuItem(value: 'stop', child: Text('Stop')),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
}
