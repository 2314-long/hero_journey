import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/task.dart';

class TaskTile extends StatefulWidget {
  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final Future<bool> Function() onConfirmDelete;
  final VoidCallback onEdit;

  const TaskTile({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onDelete,
    required this.onConfirmDelete,
    required this.onEdit,
  });

  @override
  State<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<TaskTile> {
  late bool _localIsDone;

  @override
  void initState() {
    super.initState();
    _localIsDone = widget.task.isDone;
  }

  // 🔥 [修复点 1] 强制同步：
  // 之前那个 if (old != new) 是罪魁祸首！
  // 因为父组件“拒绝”了修改，所以 old 和 new 都是 true，导致这里不执行，
  // 结果 _localIsDone 还是 false (你点击后的状态)，于是 UI 就显示没钩了。
  // 现在无论如何，都强制和父组件保持一致！
  @override
  void didUpdateWidget(covariant TaskTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    _localIsDone = widget.task.isDone;
  }

  // 🔥 [修复点 2] 拦截动画：
  // 如果任务已经是完成状态，根本不要去动 _localIsDone，
  // 这样 UI 连“闪一下”都不会有，直接通知父组件弹窗。
  void _handleTap() async {
    if (widget.task.isDone) {
      widget.onToggle(); // 直接喊父组件处理（弹窗）
      return; // 自己什么都不做，UI 保持原样
    }

    if (_localIsDone != widget.task.isDone) return;
    setState(() => _localIsDone = !_localIsDone);
    await Future.delayed(const Duration(milliseconds: 500));
    widget.onToggle();
  }

  // --- 下面的代码保持原样 ---

  bool _isOverdue(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return false;
    try {
      return DateTime.now().isAfter(DateTime.parse(dateStr));
    } catch (e) {
      return false;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "";
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
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isOverdue = !_localIsDone && _isOverdue(widget.task.deadline);
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Slidable(
        key: ValueKey(widget.task.id),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          dismissible: DismissiblePane(
            onDismissed: () => widget.onDelete(),
            confirmDismiss: () async {
              return await widget.onConfirmDelete();
            },
          ),
          children: [
            SlidableAction(
              onPressed: (context) => widget.onEdit(),
              backgroundColor: Colors.blue.shade100,
              foregroundColor: Colors.blue.shade700,
              icon: Icons.edit_rounded,
              label: '编辑',
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16),
              ),
            ),
            SlidableAction(
              onPressed: (context) async {
                final confirm = await widget.onConfirmDelete();
                if (confirm) {
                  widget.onDelete();
                }
              },
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: _localIsDone ? Colors.grey.shade50 : colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: isOverdue && !_localIsDone
                ? Border.all(
                    color: colorScheme.error.withValues(alpha: 0.5),
                    width: 1.5,
                  )
                : Border.all(color: Colors.transparent, width: 0),
            boxShadow: _localIsDone
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: isOverdue ? null : _handleTap,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  _AnimatedCheckbox(
                    isChecked: _localIsDone,
                    color: isOverdue ? Colors.grey : colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: _localIsDone
                                ? FontWeight.normal
                                : FontWeight.w600,
                            decoration: _localIsDone
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                            decorationColor: Colors.grey.shade400,
                            color: _localIsDone
                                ? Colors.grey.shade400
                                : (isOverdue
                                      ? Colors.grey.shade700
                                      : Colors.black87),
                          ),
                          child: Text(widget.task.title),
                        ),
                        if (widget.task.deadline != null &&
                            widget.task.deadline!.isNotEmpty) ...[
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
                                "${_formatDate(widget.task.deadline)} ${isOverdue ? (widget.task.punished ? '(已惩罚)' : '(已过期)') : ''}",
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

class _AnimatedCheckbox extends StatelessWidget {
  final bool isChecked;
  final Color color;
  const _AnimatedCheckbox({required this.isChecked, required this.color});
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.elasticOut,
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isChecked ? color : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isChecked ? color : Colors.grey.shade400,
          width: 2,
        ),
      ),
      child: isChecked
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : null,
    );
  }
}
