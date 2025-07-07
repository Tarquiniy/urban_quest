import 'package:urban_quest/models/team_member.dart';
import 'package:flutter/material.dart';

class MemberListTile extends StatelessWidget {
  final TeamMember member;
  final Color color;
  final bool isCaptain;
  final Function(String)? onRoleChange;
  final Function()? onMemberRemove;

  const MemberListTile({
    Key? key,
    required this.member,
    required this.color,
    required this.isCaptain,
    this.onRoleChange,
    this.onMemberRemove,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage:
            member.avatarUrl != null ? NetworkImage(member.avatarUrl!) : null,
        child: member.avatarUrl == null
            ? Text(member.username[0].toUpperCase())
            : null,
      ),
      title: Text(member.username),
      subtitle: Text(member.role ?? 'участник'),
      trailing: isCaptain ? _buildCaptainActions(context) : null,
    );
  }

  Widget _buildCaptainActions(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: color),
      onSelected: (value) {
        if (value == 'remove' && onMemberRemove != null) {
          onMemberRemove!();
        } else if (onRoleChange != null) {
          onRoleChange!(value);
        }
      },
      itemBuilder: (BuildContext context) => [
        const PopupMenuItem(
          value: 'участник',
          child: Text('Сделать участником'),
        ),
        const PopupMenuItem(
          value: 'модератор',
          child: Text('Сделать модератором'),
        ),
        const PopupMenuItem(
          value: 'remove',
          child:
              Text('Удалить из команды', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }
}
