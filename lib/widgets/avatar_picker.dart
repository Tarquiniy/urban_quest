import 'package:flutter/material.dart';

class AvatarPicker extends StatefulWidget {
  final String? initialAvatarUrl;
  final ValueChanged<String> onAvatarSelected;

  const AvatarPicker(
      {Key? key, this.initialAvatarUrl, required this.onAvatarSelected})
      : super(key: key);

  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<AvatarPicker> {
  String? _selectedAvatarUrl;

  @override
  void initState() {
    super.initState();
    _selectedAvatarUrl = widget.initialAvatarUrl;
  }

  final List<String> _avatarUrls = [
    'assets/avatars/avatar1.png',
    'assets/avatars/avatar2.png',
    'assets/avatars/avatar3.png',
    'assets/avatars/avatar4.png',
    'assets/avatars/avatar5.png',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _avatarUrls
            .map((url) => GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedAvatarUrl = url;
                    });
                    widget.onAvatarSelected(url);
                  },
                  child: Container(
                    margin: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      border: _selectedAvatarUrl == url
                          ? Border.all(
                              color: Theme.of(context).primaryColor, width: 2.0)
                          : null,
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Image.asset(
                        url,
                        width: 80.0,
                        height: 80.0,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}
