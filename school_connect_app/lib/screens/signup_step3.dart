import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/auth_provider.dart';
import '../models/school_model.dart';
import '../models/student_group_model.dart';
import '../widgets/auth_scaffold.dart';

class SignupStep3 extends ConsumerStatefulWidget {
  const SignupStep3({super.key});

  @override
  ConsumerState<SignupStep3> createState() => _SignupStep3State();
}

class _SignupStep3State extends ConsumerState<SignupStep3> {
  SchoolModel? _selectedSchool;
  StudentGroupModel? _selectedClass;

  List<SchoolModel> _schools = const [];
  List<StudentGroupModel> _classes = const [];
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? get _data =>
      ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(sheetsServiceProvider);
      final programs = await api.getPrograms();
      final groups = await api.getStudentGroups();
      if (!mounted) return;
      setState(() {
        _schools = programs;
        _classes = groups;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load schools: $e';
      });
    }
  }

  void _next() {
    if (_selectedSchool == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a school.')),
      );
      return;
    }
    final merged = {...?_data, ...{
      'school': _selectedSchool!.id,
      'schoolName': _selectedSchool!.name,
      'studentGroup': _selectedClass?.id,
      'studentGroupName': _selectedClass?.name,
    }};
    Navigator.pushNamed(context, '/SignupStep4', arguments: merged);
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      icon: Icons.apartment_rounded,
      title: 'Your school',
      subtitle: 'Pick the school and class you belong to',
      currentStep: 3,
      footer: _buildFooter(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Column(
              children: [
                Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _load,
                  child: const Text('Retry'),
                ),
              ],
            )
          else ...[
            DropdownButtonFormField<SchoolModel>(
              initialValue: _selectedSchool,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'School / Program',
                prefixIcon: Icon(Icons.school_outlined),
              ),
              items: _schools.map((school) {
                return DropdownMenuItem(
                  value: school,
                  child: Text(school.name, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (school) {
                setState(() {
                  _selectedSchool = school;
                  _selectedClass = null;
                });
              },
            ),
            if (_selectedSchool != null) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<StudentGroupModel>(
                initialValue: _selectedClass,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Class',
                  hintText: 'Select your class',
                  prefixIcon: Icon(Icons.class_outlined),
                ),
                items: _classes
                    .where((c) => c.program == _selectedSchool!.id)
                    .map((cls) {
                  return DropdownMenuItem(
                    value: cls,
                    child: Text(cls.name, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (cls) => setState(() => _selectedClass = cls),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Back', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _next,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Next', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ],
    );
  }
}
