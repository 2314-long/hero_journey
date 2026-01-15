import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class MonthlyCalendarCard extends StatefulWidget {
  final List<dynamic> historyLogs;

  const MonthlyCalendarCard({super.key, required this.historyLogs});

  @override
  State<MonthlyCalendarCard> createState() => _MonthlyCalendarCardState();
}

class _MonthlyCalendarCardState extends State<MonthlyCalendarCard> {
  Map<DateTime, List<String>> _events = {};
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('zh_CN', null).then((_) {
      if (mounted) setState(() {});
    });
    _parseEvents();
  }

  void _parseEvents() {
    _events = {};
    for (var log in widget.historyLogs) {
      try {
        DateTime date = DateTime.parse(log['log_date']);
        DateTime key = DateTime.utc(date.year, date.month, date.day);
        String tasksStr = log['finished_tasks'] ?? "";
        if (tasksStr.isNotEmpty) {
          _events[key] = tasksStr.split('|');
        } else {
          _events[key] = [];
        }
      } catch (e) {
        print("日期解析失败: $e");
      }
    }
  }

  @override
  void didUpdateWidget(covariant MonthlyCalendarCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _parseEvents();
  }

  List<String> _getEventsForDay(DateTime day) {
    DateTime key = DateTime.utc(day.year, day.month, day.day);
    return _events[key] ?? [];
  }

  Color _getHeatmapColor(int count) {
    if (count == 0) return Colors.transparent;
    if (count <= 2) return Colors.green.shade200;
    if (count <= 4) return Colors.green.shade400;
    if (count <= 6) return Colors.green.shade600;
    return Colors.green.shade900;
  }

  Color _getTextColor(int count) {
    if (count > 4) return Colors.white;
    return Colors.black87;
  }

  Widget _buildDayItem(
    BuildContext context,
    DateTime day, {
    bool isSelected = false,
    bool isToday = false,
  }) {
    final tasks = _getEventsForDay(day);
    final int count = tasks.length;
    final Color heatmapColor = _getHeatmapColor(count);

    BoxBorder? border;
    if (isSelected) {
      border = Border.all(color: Colors.black, width: 2);
    } else if (isToday && count == 0) {
      border = Border.all(color: Colors.orange, width: 2);
    }

    return Container(
      margin: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: heatmapColor,
        shape: BoxShape.circle,
        border: border,
      ),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: TextStyle(
          color: (isToday && count == 0)
              ? Colors.deepOrange
              : _getTextColor(count),
          fontWeight: (isSelected || isToday)
              ? FontWeight.bold
              : FontWeight.normal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedTasks = _getEventsForDay(_selectedDay);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "英雄纪事 (热力图)",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          TableCalendar(
            locale: 'zh_CN',
            firstDay: DateTime.utc(2025, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),

            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            calendarStyle: const CalendarStyle(outsideDaysVisible: false),

            eventLoader: _getEventsForDay,

            calendarBuilders: CalendarBuilders(
              // 🔥 [新增] 强制隐藏标记点（那些小黑点）
              markerBuilder: (context, day, events) => const SizedBox.shrink(),

              // 其他构建器保持不变
              defaultBuilder: (context, day, focusedDay) {
                return _buildDayItem(context, day);
              },
              selectedBuilder: (context, day, focusedDay) {
                return _buildDayItem(context, day, isSelected: true);
              },
              todayBuilder: (context, day, focusedDay) {
                return _buildDayItem(context, day, isToday: true);
              },
            ),

            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
          ),

          const Divider(height: 32),

          Text(
            "${_selectedDay.month}月${_selectedDay.day}日 的战绩",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          const SizedBox(height: 12),

          if (selectedTasks.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  "这一天还没留下传说...",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: selectedTasks.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 20,
                  ),
                  title: Text(
                    selectedTasks[index],
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
