import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AddTaskDialog extends StatefulWidget {
  // [新增] 接收初始值，用于编辑模式
  final String? initialTitle;
  final DateTime? initialDeadline;

  final Function(String title, DateTime? deadline) onSubmit;

  const AddTaskDialog({
    super.key,
    this.initialTitle,
    this.initialDeadline,
    required this.onSubmit,
  });

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  final TextEditingController _taskController = TextEditingController();
  DateTime? _selectedDeadline;

  @override
  void initState() {
    super.initState();
    // [新增] 如果有初始值，就填进去
    if (widget.initialTitle != null) {
      _taskController.text = widget.initialTitle!;
    }
    _selectedDeadline = widget.initialDeadline;
  }

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline ?? now, // 编辑时默认定位到已选日期
      firstDate: now.subtract(const Duration(days: 365)), // 允许选以前的日期补录?
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _selectedDeadline ?? now.add(const Duration(minutes: 30)),
      ),
    );
    if (time == null) return;
    setState(
      () => _selectedDeadline = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // 判断是“发布”还是“编辑”
    final isEditing = widget.initialTitle != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.all(24),
      title: Row(
        children: [
          Icon(
            isEditing ? Icons.edit_note_rounded : Icons.add_task_rounded,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Text(
            isEditing ? "编辑挑战" : "发布新挑战",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _taskController,
            decoration: const InputDecoration(
              hintText: "例如：背 20 个单词",
              prefixIcon: Icon(Icons.edit_outlined),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          Material(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: _pickDateTime,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedDeadline == null
                            ? "设置截止时间 (可选)"
                            : DateFormat(
                                'MM月dd日 HH:mm',
                              ).format(_selectedDeadline!),
                        style: TextStyle(
                          color: _selectedDeadline == null
                              ? Colors.grey.shade600
                              : colorScheme.primary,
                          fontWeight: _selectedDeadline == null
                              ? FontWeight.normal
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_selectedDeadline != null)
                      Icon(
                        Icons.edit,
                        size: 16,
                        color: colorScheme.primary.withValues(alpha: 0.5),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("取消", style: TextStyle(color: Colors.grey.shade600)),
        ),
        FilledButton.icon(
          onPressed: () {
            if (_taskController.text.isNotEmpty) {
              widget.onSubmit(_taskController.text, _selectedDeadline);
              Navigator.pop(context);
            }
          },
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: Icon(isEditing ? Icons.save_rounded : Icons.check_rounded),
          label: Text(isEditing ? "保存修改" : "确定发布"),
        ),
      ],
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
    );
  }
}
