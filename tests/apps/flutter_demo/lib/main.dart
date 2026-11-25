// x86Sim flutter_demo: a Flutter app for the agent tools (tests/ax/games_e2e.py flutter). Its semantics tree (what
// the snapshot reads, simax_engines.m) has a button, a text field (Semantics(identifier:): id name-field), a switch and a list.
import 'package:flutter/material.dart';

void main() => runApp(const DemoApp());

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(title: 'Flutter Demo', home: Home());
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int taps = 0;
  bool on = false;
  String typed = '';
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flutter Demo')),
      body: Column(children: [
        // (a Semantics(identifier:) around the button would sit on a parent node, not on the button's own)
        ElevatedButton(onPressed: () => setState(() => taps++), child: const Text('Tap me')),
        Text('Taps: $taps'),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Semantics(
            identifier: 'name-field',
            child: TextField(
              decoration: const InputDecoration(labelText: 'Your name'),
              onChanged: (v) => setState(() => typed = v),
            ),
          ),
        ),
        Text('Typed: $typed'),
        SwitchListTile(title: const Text('Dark mode'), value: on, onChanged: (v) => setState(() => on = v)),
        Expanded(
          child: ListView.builder(
            itemCount: 50,
            itemBuilder: (c, i) => ListTile(title: Text('Row $i')),
          ),
        ),
      ]),
    );
  }
}
