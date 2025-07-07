import 'package:urban_quest/constants.dart';
import 'package:urban_quest/widgets/cached_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:urban_quest/models/team.dart';
import 'package:urban_quest/providers/team_provider.dart';

class TeamCustomizationScreen extends StatefulWidget {
  final Team team;

  const TeamCustomizationScreen({Key? key, required this.team})
      : super(key: key);

  @override
  _TeamCustomizationScreenState createState() =>
      _TeamCustomizationScreenState();
}

class _TeamCustomizationScreenState extends State<TeamCustomizationScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mottoController = TextEditingController();
  Color _currentColor = Colors.deepPurple;
  String _currentColorName = 'Тёмно-Фиолетовый';
  bool _isLoading = false;
  List<String> _availableAvatars = [];
  List<String> _availableBanners = [];
  bool _isLoadingAvatars = false;
  bool _isLoadingBanners = false;
  String? _selectedAvatar; // Добавляем состояние для выбранного аватара
  String? _selectedBanner; // Добавляем состояние для выбранного баннера

  final Map<Color, String> _colorNames = {
    Colors.blue: 'Синий',
    Colors.red: 'Красный',
    Colors.green: 'Зеленый',
    Colors.purple: 'Фиолетовый',
    Colors.orange: 'Оранжевый',
    Colors.yellow: 'Желтый',
    Colors.pink: 'Розовый',
    Colors.teal: 'Бирюзовый',
    Colors.indigo: 'Индиго',
    Colors.cyan: 'Голубой',
    Colors.lime: 'Лаймовый',
    Colors.amber: 'Янтарный',
  };

  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.team.name;
    _mottoController.text = widget.team.motto ?? '';
    _currentColor = _parseColor(widget.team.colorScheme) ?? Colors.blue;
    _currentColorName = _getColorName(_currentColor);
    _loadAvailableImages();
  }

  Color? _parseColor(String? colorValue) {
    if (colorValue == null || colorValue.isEmpty) return null;

    if (colorValue.startsWith('#')) {
      try {
        return Color(int.parse(colorValue.replaceFirst('#', '0xff')));
      } catch (e) {
        debugPrint('Error parsing color: $e');
        return null;
      }
    }

    final colorMap = {
      'blue': Colors.blue,
      'red': Colors.red,
      'green': Colors.green,
      'purple': Colors.purple,
      'orange': Colors.orange,
    };

    return colorMap[colorValue.toLowerCase()];
  }

  String _getColorName(Color color) {
    return _colorNames[color] ??
        'Пользовательский (${color.value.toRadixString(16).substring(2)})';
  }

  Future<void> _loadAvailableImages() async {
    await _loadAvailableAvatars();
  }

  Future<void> _loadAvailableAvatars() async {
    setState(() => _isLoadingAvatars = true);
    try {
      final response =
          await _supabase.storage.from(Constants.teamAvatarsBucket).list();

      setState(() {
        _availableAvatars = response
            .where((file) => !file.name.endsWith('/'))
            .map((file) => file.name)
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading avatars: $e');
    } finally {
      setState(() => _isLoadingAvatars = false);
    }
  }

  String _getFullAvatarUrl(String fileName) {
    if (fileName.startsWith('http')) return fileName;
    return '${Constants.storageBaseUrl}/object/public/${Constants.teamAvatarsBucket}/$fileName';
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Выберите цвет команды'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: _currentColor,
              onColorChanged: (Color color) {
                setState(() {
                  _currentColor = color;
                  _currentColorName = _getColorName(color);
                });
              },
              pickerAreaHeightPercent: 0.8,
              enableAlpha: false,
              displayThumbColor: true,
              colorPickerWidth: 300,
              paletteType: PaletteType.hsvWithHue,
              pickerAreaBorderRadius: BorderRadius.circular(16),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Готово'),
              onPressed: () {
                Navigator.of(context).pop();
                _applyColorChanges();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _applyColorChanges() async {
    final colorHex = '#${_currentColor.value.toRadixString(16).substring(2)}';
    final teamProvider = Provider.of<TeamProvider>(context, listen: false);

    try {
      await teamProvider.updateTeamAppearance(
        teamId: widget.team.id,
        colorScheme: colorHex,
      );

      // Обновляем локальные данные
      final updatedTeam = widget.team.copyWith(colorScheme: colorHex);
      teamProvider.setCurrentTeam(updatedTeam);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Цвет команды обновлен')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка обновления цвета: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _updateTeamAvatar(String fileName) async {
    try {
      setState(() {
        _isLoading = true;
        _selectedAvatar = fileName; // Обновляем локальное состояние
      });

      final teamProvider = Provider.of<TeamProvider>(context, listen: false);
      await teamProvider.updateTeamAppearance(
        teamId: widget.team.id,
        imageUrl: fileName,
      );

      // Обновляем локальное состояние команды
      final updatedTeam = widget.team.copyWith(imageUrl: fileName);
      teamProvider.setCurrentTeam(updatedTeam);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Аватар команды обновлен')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка обновления: ${e.toString()}')),
        );
        // В случае ошибки возвращаем предыдущее значение
        setState(() => _selectedAvatar = widget.team.imageUrl);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateTeamBanner(String fileName) async {
    try {
      setState(() {
        _isLoading = true;
        _selectedBanner = fileName; // Обновляем локальное состояние
      });

      final teamProvider = Provider.of<TeamProvider>(context, listen: false);
      await teamProvider.updateTeamAppearance(
        teamId: widget.team.id,
        bannerUrl: fileName,
      );

      // Обновляем локальное состояние команды
      final updatedTeam = widget.team.copyWith(bannerUrl: fileName);
      teamProvider.setCurrentTeam(updatedTeam);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Баннер команды обновлен')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка обновления: ${e.toString()}')),
        );
        // В случае ошибки возвращаем предыдущее значение
        setState(() => _selectedBanner = widget.team.bannerUrl);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges() async {
    try {
      setState(() => _isLoading = true);
      final colorHex = '#${_currentColor.value.toRadixString(16).substring(2)}';
      final teamProvider = Provider.of<TeamProvider>(context, listen: false);

      await teamProvider.updateTeamAppearance(
        teamId: widget.team.id,
        name: _nameController.text,
        motto: _mottoController.text,
        colorScheme: colorHex,
      );

      // Загружаем обновленные данные команды
      await teamProvider
          .loadUserTeams(teamProvider.currentTeam?.creatorId ?? '');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Настройки команды сохранены')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Provider.of<TeamProvider>(context);

    return WillPopScope(
      onWillPop: () async {
        await _saveChanges();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Настройки команды'),
          backgroundColor: _currentColor.withOpacity(0.7),
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _isLoading ? null : _saveChanges,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTeamAvatarPreview(theme),
                    const SizedBox(height: 20),
                    _buildNameField(),
                    const SizedBox(height: 20),
                    _buildMottoField(),
                    const SizedBox(height: 20),
                    _buildColorSelector(),
                    const SizedBox(height: 20),
                    _buildColorPreviewElements(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildTeamAvatarPreview(ThemeData theme) {
    // Используем _selectedAvatar, если он есть, иначе берем из widget.team
    final currentAvatar = _selectedAvatar ?? widget.team.imageUrl;

    return Column(
      children: [
        const Text('Текущий аватар команды'),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _isLoading ? null : () => _showAvatarSelectionDialog(),
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(color: theme.primaryColor, width: 2),
              borderRadius: BorderRadius.circular(60),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(58),
              child: CachedImage(
                imageUrl: _getFullAvatarUrl(currentAvatar),
                width: 120,
                height: 120,
                errorWidget: const Icon(Icons.group, size: 50),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          icon: const Icon(Icons.collections),
          label: const Text('Выбрать аватар из коллекции'),
          onPressed: _isLoading ? null : () => _showAvatarSelectionDialog(),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: _currentColor),
          ),
        ),
      ],
    );
  }

  Widget _buildColorPreviewElements() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Примеры элементов с выбранным цветом:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _currentColor,
                shape: BoxShape.circle,
              ),
            ),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: _currentColor,
              ),
              child: const Text('Кнопка'),
            ),
            Chip(
              label: const Text('Тег'),
              backgroundColor: _currentColor.withOpacity(0.2),
              labelStyle: TextStyle(color: _currentColor),
            ),
            Container(
              width: 100,
              height: 20,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _currentColor,
                    _currentColor.withOpacity(0.5),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: InputDecoration(
        labelText: 'Название команды',
        border: OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: _currentColor),
        ),
      ),
    );
  }

  Widget _buildMottoField() {
    return TextFormField(
      controller: _mottoController,
      decoration: InputDecoration(
        labelText: 'Девиз команды',
        border: OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: _currentColor),
        ),
      ),
      maxLines: 2,
    );
  }

  Widget _buildColorSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Цвет команды',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _showColorPicker,
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: _currentColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: _currentColor.withOpacity(0.4),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Text(
                _currentColorName,
                style: TextStyle(
                  color: _currentColor.computeLuminance() > 0.5
                      ? Colors.black
                      : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text('Нажмите для выбора цвета',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Future<void> _showAvatarSelectionDialog() async {
    if (_isLoadingAvatars) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выберите аватар'),
        content: _isLoadingAvatars
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
                        final imageUrl =
                            _getFullAvatarUrl(_availableAvatars[index]);
                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            _updateTeamAvatar(_availableAvatars[index]);
                          },
                          child: Image.network(
                            imageUrl,
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
}
