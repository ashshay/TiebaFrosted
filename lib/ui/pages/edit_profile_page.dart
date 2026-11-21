import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repo.dart';
import '../widgets/common.dart';

/// 编辑个人资料页（昵称、简介、性别）。
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, required this.user});

  final TiebaUser user;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _nick = TextEditingController(
    text: widget.user.nameShow.isNotEmpty
        ? widget.user.nameShow
        : widget.user.name,
  );
  late final TextEditingController _intro = TextEditingController(
    text: widget.user.intro,
  );
  late int _sex = widget.user.sex; // 1=男, 2=女
  bool _saving = false;

  @override
  void dispose() {
    _nick.dispose();
    _intro.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await context.read<TiebaRepo>().modifyProfile(
        nickName: _nick.text.trim(),
        intro: _intro.text.trim(),
        sex: _sex,
      );
      if (!mounted) return;
      showFrostedToast(context, '资料已保存');
      Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showFrostedToast(context, cleanError(e), level: BannerLevel.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FrostedPage(
      title: '编辑资料',
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '保存中' : '保存'),
          ),
        ),
      ],
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          14,
          pageTopInset(context) + 10,
          14,
          MediaQuery.paddingOf(context).bottom + 24,
        ),
        children: [
          const FrostedSectionTitle('昵称'),
          FrostedCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: TextField(
              controller: _nick,
              decoration: const InputDecoration(hintText: '输入昵称'),
            ),
          ),
          const FrostedSectionTitle('简介'),
          FrostedCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              controller: _intro,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(hintText: '写点个人介绍...'),
            ),
          ),
          const FrostedSectionTitle('性别'),
          FrostedCard(
            child: SegmentedControl<int>(
              value: _sex == 2 ? 2 : 1,
              onChanged: (v) => setState(() => _sex = v),
              segments: const [
                (1, '男'),
                (2, '女'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
