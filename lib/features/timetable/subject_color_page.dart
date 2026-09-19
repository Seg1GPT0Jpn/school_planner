import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../../widgets/color_palette_picker.dart';
import 'subject_colors.dart';
import 'timetable_repository.dart';

/// 教科の色を選ぶ画面
class SubjectColorPage extends StatefulWidget {
  const SubjectColorPage({super.key});

  @override
  State<SubjectColorPage> createState() => _SubjectColorPageState();
}

class _SubjectColorPageState extends State<SubjectColorPage> {
  late final Stream<TimetableData> _stream;
  late final SubjectColorRepository _colorRepository;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    _stream = TimetableRepository(uid: uid).watch();
    _colorRepository = SubjectColorRepository(uid: uid);
  }

  Future<void> _pickColor(String category) async {
    final picked = await showColorPalettePicker(
      context,
      initial: subjectColorOf(context, category),
    );
    if (picked != null) {
      await _colorRepository.setColor(category, picked.toARGB32());
    }
  }

  @override
  Widget build(BuildContext context) {
    final customColors = SubjectColorScope.customColorsOf(context);

    return Scaffold(
      appBar: AppBar(title: const Text('教科の色')),
      body: StreamBuilder<TimetableData>(
        stream: _stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final subjects = snapshot.data!.subjects;

          // 教科（国語・数学…）を、科目一覧の順番で重複なく並べる
          final categories = <String>[];
          for (final s in subjects) {
            if (!categories.contains(s.category)) categories.add(s.category);
          }

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                children: [
                  for (final category in categories)
                    ListTile(
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: subjectColorOf(context, category),
                      ),
                      title: Text(category),
                      // その教科の科目を小さく表示
                      subtitle: Text(
                        subjects
                            .where((s) => s.category == category)
                            .map((s) => s.name)
                            .join('・'),
                      ),
                      trailing: customColors.containsKey(category)
                          ? TextButton(
                              onPressed: () =>
                                  _colorRepository.resetColor(category),
                              child: const Text('既定に戻す'),
                            )
                          : null,
                      onTap: () => _pickColor(category),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
