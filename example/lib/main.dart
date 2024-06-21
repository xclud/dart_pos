import 'dart:io';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POS Device',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'POS Device'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _amountController = TextEditingController(text: '10001');
  final _hostController = TextEditingController(text: '192.168.1.2');
  Socket? s;

  String? _terminalId;

  final List<String> _messages = [];

  void _purchaseSerial() async {}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Form(
        child: ListView(
          padding: const EdgeInsets.all(4),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: TextFormField(
                controller: _hostController,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: TextFormField(
                controller: _amountController,
              ),
            ),
            if (_terminalId != null && _terminalId!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: Text('Terminal Id: $_terminalId'),
              ),
            ..._messages.map((e) => Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Text(e),
                )),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _purchaseSerial,
        tooltip: 'Purchase',
        child: const Icon(Icons.shopping_cart),
      ),
    );
  }
}
