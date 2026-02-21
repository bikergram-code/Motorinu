import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

class EditStepDialog extends StatefulWidget {
  final Map<String, dynamic> step;
  final Function(String title, String description, String notes) onSave;

  const EditStepDialog({super.key, required this.step, required this.onSave});

  @override
  State<EditStepDialog> createState() => _EditStepDialogState();
}

class _EditStepDialogState extends State<EditStepDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.step["title"] ?? '');
    _descriptionController = TextEditingController(
      text: widget.step["description"] ?? '',
    );
    _notesController = TextEditingController(text: widget.step["notes"] ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onSave(
        _titleController.text.trim(),
        _descriptionController.text.trim(),
        _notesController.text.trim(),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: Container(
        constraints: BoxConstraints(maxHeight: 80.h),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(6.w),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Schritt bearbeiten',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Titel'),
                    textCapitalization: TextCapitalization.sentences,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Bitte Titel eingeben';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 2.h),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Beschreibung',
                    ),
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Bitte Beschreibung eingeben';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 2.h),
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notizen (optional)',
                      hintText: 'Zusätzliche Hinweise oder Beobachtungen',
                    ),
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  SizedBox(height: 3.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Abbrechen'),
                      ),
                      SizedBox(width: 2.w),
                      ElevatedButton(
                        onPressed: _submit,
                        child: const Text('Speichern'),
                      ),
                    ],
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
