import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart'; // [新增] 引入侧滑库
import '../models/task.dart';

class TaskTile extends StatelessWidget {
  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit; // [新增] 编辑回调

  const TaskTile({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
  });

  bool _isOverdue(String? dateStr) {
    if (dateStr == null) return false;
    return DateTime.now().isAfter(DateTime.parse(dateStr));
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return "";
    final date = DateTime.parse(dateStr);
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return '今天 ${DateFormat('HH:mm').format(date)}';
    }
    return DateFormat('MM月dd日 HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    bool isOverdue = !task.isDone && _isOverdue(task.deadline);
    final colorScheme = Theme.of(context).colorScheme;

    // [修改] 使用 Padding + Slidable + Card 的组合
    // 这样滑动的 Action 才能和 Card 高度一致，且不遮挡 Margin
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Slidable(
        // key 用于列表复用优化
        key: ValueKey(task.id),

        // [核心] 右侧侧滑菜单 (从右往左滑)
        endActionPane: ActionPane(
          motion: const ScrollMotion(), // 滑动效果：平滑滚动
          children: [
            // 编辑按钮 (蓝色)
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
            // 删除按钮 (红色)
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

        // 这里的 Card 必须去掉 margin，因为 margin 已经由外层的 Padding 提供了
        child: Card(
          elevation: task.isDone ? 0.5 : 2,
          color: task.isDone ? Colors.grey.shade50 : colorScheme.surface,
          margin: EdgeInsets.zero, // [注意] 设为0，否则滑动时会有缝隙
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
                        if (task.deadline != null) ...[
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
