import 'dart:convert';

import 'package:flutter/material.dart';

import 'server_profiles.dart';

/// Add/edit form for a single server profile. Extracted from the old
/// `ProfilesPage` so the Server Nodes tab (Milestone 6.2) can reuse it
/// without a dedicated page to navigate to.
class ProfileFormDialog extends StatefulWidget {
  const ProfileFormDialog({super.key, this.existing});

  final ServerProfile? existing;

  @override
  State<ProfileFormDialog> createState() => _ProfileFormDialogState();
}

class _ProfileFormDialogState extends State<ProfileFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.existing?.name ?? '');
  late final _serverIpController = TextEditingController(text: widget.existing?.serverIp ?? '');
  late final _configController = TextEditingController(text: widget.existing?.configJson ?? '');

  void _tryDetectServerIp() {
    try {
      final data = jsonDecode(_configController.text) as Map<String, dynamic>;
      final outbounds = data['outbounds'] as List;
      final settings = (outbounds.first as Map<String, dynamic>)['settings'] as Map<String, dynamic>;
      final vnext = (settings['vnext'] as List).first as Map<String, dynamic>;
      final address = vnext['address'] as String;
      setState(() => _serverIpController.text = address);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nggak bisa deteksi otomatis, isi server IP manual ya.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Tambah Server Profile' : 'Edit Server Profile'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nama'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                ),
                TextFormField(
                  controller: _configController,
                  decoration: const InputDecoration(labelText: 'Client config JSON (dari server)'),
                  maxLines: 6,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                    try {
                      jsonDecode(v);
                    } catch (_) {
                      return 'Bukan JSON yang valid';
                    }
                    return null;
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _tryDetectServerIp,
                    child: const Text('Deteksi server IP dari config'),
                  ),
                ),
                TextFormField(
                  controller: _serverIpController,
                  decoration: const InputDecoration(labelText: 'Server IP'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(ServerProfile(
              id: widget.existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
              name: _nameController.text.trim(),
              serverIp: _serverIpController.text.trim(),
              configJson: _configController.text.trim(),
            ));
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
