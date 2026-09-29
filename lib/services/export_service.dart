import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/prospect.dart';

class ExportService {
  const ExportService();

  Future<File> createProspectsCsv(List<Prospect> prospects) async {
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/prospecto_export_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv',
    );
    final buffer = StringBuffer()
      ..writeln(
        'Nom;Adresse;Catégorie;Téléphone;Email;Statut;Priorité;Durée visite;Prochaine visite;Note',
      );
    for (final p in prospects) {
      buffer.writeln([
        p.name,
        p.address,
        p.category,
        p.phone ?? '',
        p.email ?? '',
        p.status ?? '',
        p.priority,
        p.visitDurationMinutes,
        p.prochaineVisite == null
            ? ''
            : DateFormat('dd/MM/yyyy HH:mm').format(p.prochaineVisite!),
        p.note ?? '',
      ].map(_csv).join(';'));
    }
    await file.writeAsString('\uFEFF${buffer.toString()}', flush: true);
    return file;
  }

  Future<File> createCalendarIcs(List<Prospect> prospects) async {
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/prospecto_relances_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.ics',
    );
    final buffer = StringBuffer()
      ..writeln('BEGIN:VCALENDAR')
      ..writeln('VERSION:2.0')
      ..writeln('PRODID:-//Digital Solution//Prospecto//FR')
      ..writeln('CALSCALE:GREGORIAN')
      ..writeln('METHOD:PUBLISH');

    for (final p in prospects.where((p) => p.prochaineVisite != null)) {
      final start = p.prochaineVisite!.toUtc();
      final end = start.add(Duration(minutes: p.visitDurationMinutes));
      final stamp = DateTime.now().toUtc();
      buffer
        ..writeln('BEGIN:VEVENT')
        ..writeln('UID:${_ics(p.id)}-${start.millisecondsSinceEpoch}@prospecto')
        ..writeln('DTSTAMP:${_icsDate(stamp)}')
        ..writeln('DTSTART:${_icsDate(start)}')
        ..writeln('DTEND:${_icsDate(end)}')
        ..writeln('SUMMARY:${_ics('Relance – ${p.name}')}')
        ..writeln('LOCATION:${_ics(p.address)}')
        ..writeln('DESCRIPTION:${_ics(p.note ?? 'Relance commerciale Prospecto')}')
        ..writeln('BEGIN:VALARM')
        ..writeln('TRIGGER:-PT24H')
        ..writeln('ACTION:DISPLAY')
        ..writeln('DESCRIPTION:${_ics('Relance ${p.name} demain')}')
        ..writeln('END:VALARM')
        ..writeln('END:VEVENT');
    }
    buffer.writeln('END:VCALENDAR');
    await file.writeAsString(buffer.toString(), flush: true);
    return file;
  }

  Future<void> shareFile(File file, {required String text}) async {
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        files: [XFile(file.path)],
      ),
    );
  }

  String _csv(Object? value) {
    final text = (value ?? '').toString().replaceAll('"', '""');
    return '"$text"';
  }

  String _icsDate(DateTime value) =>
      DateFormat("yyyyMMdd'T'HHmmss'Z'").format(value.toUtc());

  String _ics(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll('\n', '\\n')
      .replaceAll(',', '\\,')
      .replaceAll(';', '\\;');
}
