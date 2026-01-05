import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/task.dart';

class TaskTile extends StatelessWidget {
  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const TaskTile({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
  });

  // 🚀 [修复 1] 增加空字符串检查 + try-catch
  bool _isOverdue(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return false; // 同时检查 null 和 ""
    try {
      return DateTime.now().isAfter(DateTime.parse(dateStr));
    } catch (e) {
      return false; // 解析失败不算过期
    }
  }

  // 🚀 [修复 2] 增加空字符串检查 + try-catch
  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return ""; // 没日期就不显示
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        return '今天 ${DateFormat('HH:mm').format(date)}';
      }
      return DateFormat('MM月dd日 HH:mm').format(date);
    } catch (e) {
      return ""; // 解析出错就不显示
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isOverdue = !task.isDone && _isOverdue(task.deadline);
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Slidable(
        key: ValueKey(task.id),

        // 右侧侧滑菜单
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          children: [
            SlidableAction(
              onPressed: (context) => onEdit(),
              backgroundColor: Colors.blue.shade100,
              foregroundColor: Colors.blue.shade700,
              icon: Icons.edit_rounded,
              label: '编辑',
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16),
              ),
            ),
            SlidableAction(
              onPressed: (context) => onDelete(),
              backgroundColor: Colors.red.shade100,
              foregroundColor: Colors.red,
              icon: Icons.delete_rounded,
              label: '删除',
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(16),
              ),
            ),
          ],
        ),

        child: Card(
          elevation: task.isDone ? 0.5 : 2,
          color: task.isDone ? Colors.grey.shade50 : colorScheme.surface,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isOverdue && !task.isDone
                ? BorderSide(
                    color: colorScheme.error.withValues(alpha: 0.5),
                    width: 1.5,
                  )
                : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: isOverdue ? null : onToggle,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Transform.scale(
                    scale: 1.2,
                    child: Checkbox(
                      value: task.isDone,
                      onChanged: isOverdue ? null : (val) => onToggle(),
                      activeColor: colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      side: BorderSide(
                        color: isOverdue ? Colors.grey : colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: task.isDone
                                ? FontWeight.normal
                                : FontWeight.w600,
                            decoration: task.isDone
                                ? TextDecoration.lineThrough
                                : null,
                            color: task.isDone
                                ? Colors.grey.shade400
                                : (isOverdue
                                      ? Colors.grey.shade700
                                      : Colors.black87),
                          ),
                        ),
                        // 🚀 [修复 3] 显示日期前的检查
                        if (task.deadline != null &&
                            task.deadline!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                isOverdue
                                    ? Icons.error_outline
                                    : Icons.access_time_rounded,
                                size: 14,
                                color: isOverdue
                                    ? colorScheme.error
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "${_formatDate(task.deadline)} ${isOverdue ? (task.punished ? '(已惩罚)' : '(已过期)') : ''}",
                                style: TextStyle(
                                  color: isOverdue
                                      ? colorScheme.error
                                      : Colors.grey.shade600,
                                  fontSize: 12,
                                  fontWeight: isOverdue
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
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
}
