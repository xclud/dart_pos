part of '../pos.dart';

class _Field {
  const _Field(
    this.no,
    this.type,
    this.length,
    this.fixed,
    this.format,
  );

  final int no;
  final String type;
  final int length;
  final bool fixed;
  final String? format;
}
