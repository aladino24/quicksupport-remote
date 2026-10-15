import 'package:flutter/material.dart';
import 'main.dart';
import 'server_config.dart';

class ConnectHome extends StatefulWidget {
  const ConnectHome({super.key});
  @override
  State<ConnectHome> createState() => _ConnectHomeState();
}

class _ConnectHomeState extends State<ConnectHome> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  void _connect() {
    if (!_form.currentState!.validate()) return;
    final id = _id.text.replaceAll(RegExp(r'[\s-]'), '');
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => RemoteSessionScreen(
              device: DeviceModel(
                  id: id, name: 'Android $id', status: '', model: 'Android'),
              serverUrl: signalingServerUrl,
            )));
  }

  @override
  void dispose() {
    _id.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('QuickSupport Desktop')),
        body: Center(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Form(
                      key: _form,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Icon(Icons.phonelink,
                                size: 72, color: Colors.teal),
                            const SizedBox(height: 24),
                            const Text('Hubungkan ke HP',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 30, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            const Text(
                                'Buka QuickSupport di Android, lalu masukkan ID yang tampil di HP.',
                                textAlign: TextAlign.center),
                            const SizedBox(height: 28),
                            TextFormField(
                                controller: _id,
                                autofocus: true,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'ID Android',
                                    hintText: '123 456 789',
                                    border: OutlineInputBorder()),
                                validator: (value) => RegExp(r'^\d{9}$')
                                        .hasMatch((value ?? '')
                                            .replaceAll(RegExp(r'[\s-]'), ''))
                                    ? null
                                    : 'Masukkan ID 9 digit dari HP',
                                onFieldSubmitted: (_) => _connect()),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                                onPressed: _connect,
                                icon: const Icon(Icons.link),
                                label: const Padding(
                                    padding: EdgeInsets.all(14),
                                    child: Text('Connect'))),
                            const SizedBox(height: 12),
                            const Text(
                                'Pemilik HP akan diminta mengizinkan koneksi.',
                                textAlign: TextAlign.center),
                            const SizedBox(height: 24),
                          ])),
                ))),
      );
}
