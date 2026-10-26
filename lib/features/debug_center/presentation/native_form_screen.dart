import 'package:flutter/material.dart';

class NativeFormScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;

  const NativeFormScreen({super.key, this.initialData});

  @override
  State<NativeFormScreen> createState() => _NativeFormScreenState();
}

class _NativeFormScreenState extends State<NativeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  String _category = 'Support';

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialData?['title'] as String? ?? 'Yêu cầu hỗ trợ Mini App');
    _notesController = TextEditingController(text: widget.initialData?['notes'] as String? ?? '');
    _category = widget.initialData?['category'] as String? ?? 'Support';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Native Form'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Màn hình form thu thập dữ liệu Native. Khi Submit, dữ liệu sẽ được trả ngược lại Mini App!',
                          style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Tiêu đề biểu mẫu',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => val == null || val.isEmpty ? 'Vui lòng nhập tiêu đề' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'Phân loại',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Support', child: Text('Hỗ trợ kỹ thuật')),
                    DropdownMenuItem(value: 'Feedback', child: Text('Góp ý tính năng')),
                    DropdownMenuItem(value: 'Bug', child: Text('Báo lỗi')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _category = val);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú / Nội dung chi tiết',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: () {
                    if (_formKey.currentState?.validate() ?? false) {
                      Navigator.pop(context, {
                        'submitted': true,
                        'title': _titleController.text,
                        'category': _category,
                        'notes': _notesController.text,
                        'timestamp': DateTime.now().toIso8601String(),
                      });
                    }
                  },
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Gửi dữ liệu về Mini App'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
