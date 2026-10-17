import 'package:flutter/material.dart';

import '../core/app_info.dart';
import '../core/errors.dart';
import '../recipes/api.dart';
import 'recipe_widgets.dart';
import 'skeleton.dart';
import '../core/i18n.dart';

/// The admin's view of every account: who signed in, their books, how many
/// recipes they made this month, and blocking one. The server lets only the
/// admin (ADMIN_UIDS) call it.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<AdminUser>? _users;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final u = await Api.adminUsers();
      if (mounted) setState(() { _users = u; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _block(AdminUser u, bool blocked) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Api.setBlocked(u.uid, blocked);
      await _load();
    } catch (e) {
      showError(messenger, e, t('השינוי לא נשמר'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = _users;
    final muted = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Scaffold(
      appBar: AppBar(title: Text(users == null ? t('משתמשים') : t('משתמשים ({0})', [users.length]))),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _error != null && users == null
            ? ListView(children: [LoadError(_error!, retry: _load)])
            : users == null
                ? const SkeletonList(rows: 4, leading: false)
                : ListView(children: [
                    for (final u in users)
                      ListTile(
                        leading: Icon(u.admin
                            ? Icons.admin_panel_settings_outlined
                            : u.blocked
                                ? Icons.block
                                : Icons.person_outline),
                        title: Text(u.name.isEmpty ? (u.email.isEmpty ? u.uid : u.email) : u.name),
                        subtitle: Text([
                          if (u.name.isNotEmpty && u.email.isNotEmpty) u.email,
                          for (final b in u.books)
                            t('{0}: {1} מתכונים, {2} חדשים החודש', [b['title'], b['recipes'], b['createdThisMonth']]),
                          t('נכנס לאחרונה {0} · מאז {1}', [shortDateTime(u.lastSeen), shortDateTime(u.firstSeen)]),
                        ].join('\n'), style: muted),
                        isThreeLine: true,
                        trailing: u.admin
                            ? null
                            : Switch(
                                value: !u.blocked,
                                onChanged: (on) => _block(u, !on),
                              ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(t('המתג כבוי = החשבון חסום: כל בקשה שלו נדחית. הספר שלו נשמר.'),
                          style: muted),
                    ),
                  ]),
      ),
    );
  }
}
