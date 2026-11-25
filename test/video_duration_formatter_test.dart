import 'package:flutter_test/flutter_test.dart';
import 'package:exm1/features/player/domain/video_duration_formatter.dart';

void main() {
  group('VideoDurationFormatter', () {
    test('formats durations below one hour as mm:ss', () {
      expect(
        VideoDurationFormatter.format(const Duration(minutes: 4, seconds: 9)),
        '04:09',
      );
    });

    test('formats durations with hours as hh:mm:ss', () {
      expect(
        VideoDurationFormatter.format(
          const Duration(hours: 2, minutes: 3, seconds: 7),
        ),
        '2:03:07',
      );
    });

    test('formats zero duration', () {
      expect(VideoDurationFormatter.format(Duration.zero), '00:00');
    });
  });
}
