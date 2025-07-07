import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:urban_quest/models/user.dart' as app_user;
import 'package:urban_quest/providers/auth_provider.dart';
import 'package:urban_quest/constants.dart';

class AccountSettingsScreen extends StatefulWidget {
  final app_user.User user;
  const AccountSettingsScreen({Key? key, required this.user}) : super(key: key);

  @override
  _AccountSettingsScreenState createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  late TextEditingController _usernameController;
  bool _isLoading = false;
  List<String> _availableAvatars = [];
  String? _selectedAvatarName; // Храним выбранное имя аватара

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.user.username);
    _selectedAvatarName = widget.user.avatarUrl?.split('/').last;
    _loadAvailableAvatars();
  }

  Future<void> _loadAvailableAvatars() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client.storage
          .from(Constants.userAvatarsBucket)
          .list();

      setState(() {
        _availableAvatars = response
            .where((file) => !file.name.endsWith('/'))
            .map((file) => file.name)
            .toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки аватаров: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectAvatar(String avatarName) async {
    if (_selectedAvatarName == avatarName)
      return; // Не обновлять, если выбран тот же аватар

    setState(() {
      _isLoading = true;
      _selectedAvatarName = avatarName;
    });

    try {
      // Обновляем профиль пользователя, сохраняя только имя файла
      await Supabase.instance.client
          .from('users')
          .update({'avatar_url': avatarName}).eq('id', widget.user.id);

      // Обновляем состояние в провайдере
      final updatedUser = widget.user.copyWith(avatarUrl: avatarName);
      Provider.of<AuthProvider>(context, listen: false).currentUser =
          updatedUser;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Аватар успешно изменён!")),
      );
    } catch (e) {
      // В случае ошибки возвращаем предыдущее значение
      setState(
          () => _selectedAvatarName = widget.user.avatarUrl?.split('/').last);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка обновления аватара: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getCurrentAvatarUrl() {
    return _selectedAvatarName == null || _selectedAvatarName!.isEmpty
        ? '${Constants.publicStorageBaseUrl}/${Constants.userAvatarsBucket}/${Constants.defaultAvatar}'
        : '${Constants.publicStorageBaseUrl}/${Constants.userAvatarsBucket}/$_selectedAvatarName';
  }

  void _showAvatarSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выберите аватар'),
        content: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _availableAvatars.isEmpty
                ? const Text('Нет доступных аватарок')
                : SizedBox(
                    width: double.maxFinite,
                    child: GridView.builder(
                      shrinkWrap: true,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _availableAvatars.length,
                      itemBuilder: (context, index) {
                        final avatarUrl =
                            '${Constants.publicStorageBaseUrl}/${Constants.userAvatarsBucket}/${_availableAvatars[index]}';
                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            _selectAvatar(_availableAvatars[index]);
                          },
                          child: Image.network(
                            avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[200],
                                child: const Icon(Icons.broken_image),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text("Настройки аккаунта")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _isLoading ? null : _showAvatarSelectionDialog,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: NetworkImage(_getCurrentAvatarUrl()),
                backgroundColor: Colors.grey.shade300,
                child: _isLoading ? const CircularProgressIndicator() : null,
              ),
            ),
            const SizedBox(height: 10),
            const Text("Нажмите на аватар, чтобы изменить"),
            const SizedBox(height: 20),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: "Имя пользователя"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveChanges,
              child: const Text("Сохранить изменения"),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _changePassword,
              child: const Text("Сменить пароль"),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                await authProvider.logout();
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              icon: const Icon(Icons.logout),
              label: const Text("Выйти из аккаунта"),
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            ),
          ],
        ),
      ),
    );
  }

  void _saveChanges() {
    final updatedUser = widget.user.copyWith(
      username: _usernameController.text,
      avatarUrl: _selectedAvatarName,
    );
    Provider.of<AuthProvider>(context, listen: false).currentUser = updatedUser;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Изменения сохранены!")),
    );
  }

  void _changePassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Функция смены пароля в разработке")),
    );
  }
}
