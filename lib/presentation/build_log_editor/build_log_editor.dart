import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_icon_widget.dart';
import './widgets/add_step_dialog.dart';
import './widgets/cost_summary_widget.dart';
import './widgets/edit_step_dialog.dart';
import './widgets/parts_list_widget.dart';
import './widgets/project_header_widget.dart';
import './widgets/step_card_widget.dart';

class BuildLogEditor extends StatefulWidget {
  const BuildLogEditor({super.key});

  @override
  State<BuildLogEditor> createState() => _BuildLogEditorState();
}

class _BuildLogEditorState extends State<BuildLogEditor> {
  bool _isLoading = false;
  bool _hasUnsavedChanges = false;
  DateTime _lastAutoSave = DateTime.now();

  // Mock project data
  final Map<String, dynamic> _projectData = {
    "id": 1,
    "motorcycleImage":
        "https://images.unsplash.com/photo-1664533718264-b2048a8f53f1",
    "motorcycleImageLabel":
        "Black sport motorcycle with custom exhaust system parked in modern garage",
    "motorcycleName": "Yamaha YZF-R6",
    "modificationTitle": "VollstÃ¤ndiger Auspuffumbau",
    "completionPercentage": 65,
    "totalCost": 2450.0,
    "budgetLimit": 3000.0,
    "startDate": "2025-12-15",
    "lastModified": "2026-01-05",
    "steps": [
      {
        "id": 1,
        "title": "Originalauspuff entfernen",
        "description":
            "Motorrad auf MontagestÃ¤nder heben und Originalauspuff demontieren. Alle Schrauben und Dichtungen sorgfÃ¤ltig aufbewahren.",
        "beforeImage":
            "https://img.rocket.new/generatedImages/rocket_gen_img_193df9def-1767639196995.png",
        "beforeImageLabel":
            "Stock motorcycle exhaust system mounted on bike before removal",
        "afterImage":
            "https://img.rocket.new/generatedImages/rocket_gen_img_193df9def-1767639196995.png",
        "afterImageLabel":
            "Motorcycle with exhaust system removed showing mounting points",
        "isCompleted": true,
        "workDuration": 45,
        "notes":
            "Alte Dichtungen waren verschlissen und mussten ersetzt werden.",
        "timestamp": "2025-12-20T14:30:00",
      },
      {
        "id": 2,
        "title": "Neue KrÃ¼mmer montieren",
        "description":
            "Akrapovic Titan-KrÃ¼mmer mit neuen Dichtungen installieren. Anzugsmoment: 25 Nm beachten.",
        "beforeImage":
            "https://img.rocket.new/generatedImages/rocket_gen_img_154e592f9-1765464643197.png",
        "beforeImageLabel":
            "Motorcycle with exhaust system removed showing mounting points",
        "afterImage":
            "https://img.rocket.new/generatedImages/rocket_gen_img_154e592f9-1765464643197.png",
        "afterImageLabel":
            "New titanium exhaust headers installed on motorcycle engine",
        "isCompleted": true,
        "workDuration": 90,
        "notes": "Perfekte Passform, keine Anpassungen nÃ¶tig.",
        "timestamp": "2025-12-22T10:15:00",
      },
      {
        "id": 3,
        "title": "EndschalldÃ¤mpfer anbauen",
        "description":
            "Carbon-Endtopf mit Verbindungsrohr montieren und ausrichten. Alle Verbindungen auf Dichtheit prÃ¼fen.",
        "beforeImage":
            "https://img.rocket.new/generatedImages/rocket_gen_img_10760a9b7-1767639198962.png",
        "beforeImageLabel":
            "New titanium exhaust headers installed on motorcycle engine",
        "afterImage": null,
        "afterImageLabel": null,
        "isCompleted": false,
        "workDuration": 0,
        "notes": "",
        "timestamp": null,
      },
      {
        "id": 4,
        "title": "ECU-Mapping anpassen",
        "description":
            "MotorsteuergerÃ¤t mit Akrapovic-Map flashen fÃ¼r optimale Leistung und Abgaswerte.",
        "beforeImage": null,
        "beforeImageLabel": null,
        "afterImage": null,
        "afterImageLabel": null,
        "isCompleted": false,
        "workDuration": 0,
        "notes": "",
        "timestamp": null,
      },
    ],
    "parts": [
      {
        "id": 1,
        "name": "Akrapovic Titan KrÃ¼mmer",
        "price": 899.0,
        "supplier": "Louis Motorrad",
        "partNumber": "S-Y6R10-HZAAT",
        "isInstalled": true,
        "purchaseDate": "2025-12-10",
        "category": "Auspuff",
      },
      {
        "id": 2,
        "name": "Akrapovic Carbon Endtopf",
        "price": 1299.0,
        "supplier": "Louis Motorrad",
        "partNumber": "S-Y6SO8-HZC",
        "isInstalled": false,
        "purchaseDate": "2025-12-10",
        "category": "Auspuff",
      },
      {
        "id": 3,
        "name": "Dichtungssatz komplett",
        "price": 45.0,
        "supplier": "Yamaha VertragshÃ¤ndler",
        "partNumber": "5SL-14613-00",
        "isInstalled": true,
        "purchaseDate": "2025-12-18",
        "category": "Dichtungen",
      },
      {
        "id": 4,
        "name": "Akrapovic ECU-Map",
        "price": 199.0,
        "supplier": "Akrapovic Online",
        "partNumber": "MAP-Y6R-2024",
        "isInstalled": false,
        "purchaseDate": "2025-12-10",
        "category": "Elektronik",
      },
    ],
  };

  @override
  void initState() {
    super.initState();
    _startAutoSaveTimer();
  }

  void _startAutoSaveTimer() {
    Future.delayed(const Duration(minutes: 2), () {
      if (mounted && _hasUnsavedChanges) {
        _autoSave();
        _startAutoSaveTimer();
      }
    });
  }

  Future<void> _autoSave() async {
    setState(() {
      _lastAutoSave = DateTime.now();
      _hasUnsavedChanges = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Automatisch gespeichert um ${_lastAutoSave.hour}:${_lastAutoSave.minute.toString().padLeft(2, '0')}',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _markAsChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  void _addStep() {
    showDialog(
      context: context,
      builder: (context) => AddStepDialog(
        onAdd: (title, description) {
          setState(() {
            final newStep = {
              "id": (_projectData["steps"] as List).length + 1,
              "title": title,
              "description": description,
              "beforeImage": null,
              "beforeImageLabel": null,
              "afterImage": null,
              "afterImageLabel": null,
              "isCompleted": false,
              "workDuration": 0,
              "notes": "",
              "timestamp": null,
            };
            (_projectData["steps"] as List).add(newStep);
            _markAsChanged();
          });

          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Schritt hinzugefÃ¼gt')));
        },
      ),
    );
  }

  void _editStep(int index) {
    final step = (_projectData["steps"] as List)[index];
    showDialog(
      context: context,
      builder: (context) => EditStepDialog(
        step: step,
        onSave: (title, description, notes) {
          setState(() {
            step["title"] = title;
            step["description"] = description;
            step["notes"] = notes;
            _markAsChanged();
          });

          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Schritt aktualisiert')));
        },
      ),
    );
  }

  void _deleteStep(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Schritt lÃ¶schen?'),
        content: const Text(
          'MÃ¶chten Sie diesen Schritt wirklich lÃ¶schen? Diese Aktion kann nicht rÃ¼ckgÃ¤ngig gemacht werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                (_projectData["steps"] as List).removeAt(index);
                _markAsChanged();
              });
              Navigator.pop(context);
              HapticFeedback.mediumImpact();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Schritt gelÃ¶scht')));
            },
            child: const Text('LÃ¶schen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _duplicateStep(int index) {
    setState(() {
      final step = Map<String, dynamic>.from(
        (_projectData["steps"] as List)[index],
      );
      step["id"] = (_projectData["steps"] as List).length + 1;
      step["title"] = "${step["title"]} (Kopie)";
      step["isCompleted"] = false;
      step["timestamp"] = null;
      (_projectData["steps"] as List).insert(index + 1, step);
      _markAsChanged();
    });

    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Schritt dupliziert')));
  }

  void _toggleStepCompletion(int index) {
    setState(() {
      final step = (_projectData["steps"] as List)[index];
      step["isCompleted"] = !step["isCompleted"];
      if (step["isCompleted"]) {
        step["timestamp"] = DateTime.now().toIso8601String();
      } else {
        step["timestamp"] = null;
      }
      _markAsChanged();
      _updateCompletionPercentage();
    });

    HapticFeedback.lightImpact();
  }

  void _updateCompletionPercentage() {
    final steps = _projectData["steps"] as List;
    final completedSteps = steps
        .where((step) => step["isCompleted"] == true)
        .length;
    _projectData["completionPercentage"] =
        ((completedSteps / steps.length) * 100).round();
  }

  void _shareProject() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Projekt teilen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Teilen Sie Ihren Build-Log mit:'),
            const SizedBox(height: 16),
            ListTile(
              leading: CustomIconWidget(
                iconName: 'share',
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              title: const Text('Social Media'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Wird in Social Feed geteilt...'),
                  ),
                );
              },
            ),
            ListTile(
              leading: CustomIconWidget(
                iconName: 'download',
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              title: const Text('PDF exportieren'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PDF wird erstellt...')),
                );
              },
            ),
            ListTile(
              leading: CustomIconWidget(
                iconName: 'link',
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              title: const Text('Link kopieren'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Link in Zwischenablage kopiert'),
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('SchlieÃŸen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = _projectData["steps"] as List;
    final parts = _projectData["parts"] as List;

    return WillPopScope(
      onWillPop: () async {
        if (_hasUnsavedChanges) {
          final shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Ungespeicherte Ã„nderungen'),
              content: const Text(
                'Sie haben ungespeicherte Ã„nderungen. MÃ¶chten Sie wirklich zurÃ¼ckkehren?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Abbrechen'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'Verwerfen',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          );
          return shouldPop ?? false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: CustomAppBar(
          variant: AppBarVariant.standard,
          title: 'Build-Log Editor',
          automaticallyImplyLeading: true,
          actions: [
            if (_hasUnsavedChanges)
              Padding(
                padding: EdgeInsets.only(right: 2.w),
                child: Center(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            IconButton(
              icon: CustomIconWidget(
                iconName: 'share',
                color: theme.colorScheme.primary,
                size: 24,
              ),
              onPressed: _shareProject,
              tooltip: 'Projekt teilen',
            ),
            IconButton(
              icon: CustomIconWidget(
                iconName: 'save',
                color: theme.colorScheme.primary,
                size: 24,
              ),
              onPressed: () {
                _autoSave();
                HapticFeedback.mediumImpact();
              },
              tooltip: 'Speichern',
            ),
          ],
        ),
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: theme.colorScheme.secondary,
                ),
              )
            : RefreshIndicator(
                onRefresh: () async {
                  await Future.delayed(const Duration(seconds: 1));
                  setState(() {});
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProjectHeaderWidget(
                        title: 'Arbeitsschritte',
                        subtitle: 'Build Log Editor',
                      ),
                      SizedBox(height: 2.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4.w),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Arbeitsschritte',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _addStep,
                              icon: CustomIconWidget(
                                iconName: 'add',
                                color: theme.colorScheme.secondary,
                                size: 20,
                              ),
                              label: Text(
                                'Schritt',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: theme.colorScheme.secondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 1.h),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.symmetric(horizontal: 4.w),
                        itemCount: steps.length,
                        itemBuilder: (context, index) {
                          return StepCardWidget(
                            step: steps[index],
                            stepNumber: index + 1,
                            onToggleComplete: () =>
                                _toggleStepCompletion(index),
                            onEdit: () => _editStep(index),
                            onDelete: () => _deleteStep(index),
                            onDuplicate: () => _duplicateStep(index),
                          );
                        },
                      ),
                      SizedBox(height: 3.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4.w),
                        child: Text(
                          'Teileliste',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(height: 1.h),
                      PartsListWidget(
                        parts: parts,
                        onToggleInstalled: (partId) {
                          setState(() {
                            final part = parts.firstWhere(
                              (p) => p["id"] == partId,
                            );
                            part["isInstalled"] = !part["isInstalled"];
                            _markAsChanged();
                          });
                          HapticFeedback.lightImpact();
                        },
                        onAddPart: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Teil hinzufÃ¼gen')),
                          );
                        },
                      ),
                      SizedBox(height: 3.h),
                      CostSummaryWidget(
                        totalCost: _projectData["totalCost"],
                        budgetLimit: _projectData["budgetLimit"],
                        parts: parts,
                      ),
                      SizedBox(height: 10.h),
                    ],
                  ),
                ),
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addStep,
          icon: CustomIconWidget(
            iconName: 'add',
            color: theme.colorScheme.onSecondary,
            size: 24,
          ),
          label: Text(
            'Schritt',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSecondary,
            ),
          ),
          backgroundColor: theme.colorScheme.secondary,
        ),
      ),
    );
  }
}
