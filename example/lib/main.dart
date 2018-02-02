import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:pos/pos.dart';

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

  void _purchaseSerial() async {
    final message = Message.purchase(amount: 10001);
    final sp = SerialPort('COM12');
    sp.openReadWrite();

    String? _terminalId;
    bool done = false;

    final encoded = message.encode();
    final written = sp.write(encoded, timeout: 1000);

    print(written);

    while (!done) {
      final buffer = sp.read(256, timeout: 100);

      if (buffer.length < 20) {
        continue;
      }

      final msgbuf = buffer.skip(7).toList();
      final msg = Message.parse(Uint8List.fromList(msgbuf));

      if (_terminalId == null && msg.terminalId != null) {
        _terminalId = msg.terminalId;

        setState(() {});
      }

      if (_terminalId != null) {
        sp.write(Message.ack(terminalId: _terminalId).encode());
      }

      if (msg.get(39)?[0] == 48 && msg.get(37) != null) {
        print('Done');
        done = true;
      }
    }
  }

  void _purchaseSocket() async {
    final amount = int.tryParse(_amountController.text);

    if (amount == null) {
      return;
    }

    final host = _hostController.text;
    final message = Message.purchase(amount: amount);

    if (s == null) {
      s = await Socket.connect(host, 1197);

      s!.listen((event) {
        final buffer = Uint8List.fromList(event.skip(7).toList());

        try {
          final msg = Message.parse(buffer);

          if (_terminalId == null && msg.terminalId != null) {
            _terminalId = msg.terminalId;
          }

          if (_terminalId != null) {
            s!.add(Message.ack(terminalId: _terminalId!).encode());
            print('ACK');
          }

          _messages.add(msg.toString());
        } catch (_) {
          print(_.toString());
        }

        if (mounted) {
          setState(() {});
        }
      });
    }

    s!.add(message.encode());
  }

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
