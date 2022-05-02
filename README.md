[![pub package](https://img.shields.io/pub/v/pos.svg)](https://pub.dartlang.org/packages/pos)

Dart Implementation of the [ISO-8583](https://en.wikipedia.org/wiki/ISO_8583) banking protocol. Supports `03xx` message class (File Actions Message - 1987) and is compatible with most PoS devices in the market.

## Features

* Supports MAC (Message Authentication Code) calculation.
* DES Encryption.
* Written in 100% Dart.
* Works on all platforms (Android, iOS, macOS, Windows, Linux, Web).

The package also provides the following methods:

```
factory Message.parse(Uint8List data)
```

```
factory Message.conntectionTest({DateTime? dateTime})
```

```
factory Message.purchase({required int amount, DateTime? dateTime})
```

```
factory Message.ack({required String terminalId, DateTime? dateTime})
```

```
factory Message.nack({required String terminalId, DateTime? dateTime})
```

```
factory Message.eot({required String terminalId, DateTime? dateTime})
```

```
factory Message.dispose({DateTime? dateTime})
```

```
Map<String, Object> toJson()
```

## Getting started

In your `pubspec.yaml` file add:

```dart
dependencies:
  pos: any
```

## Usage

Import the package:

```dart
import 'package:pos/pos.dart';
```

Then:

```dart
final iso8583Message = Message.parse(Uint8List);
```

## Additional information

Please look at the `./example` directory for a working demo using `TCP` and `SerialPort`.
