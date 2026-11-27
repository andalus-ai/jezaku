import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/frame_styles/models/frame_look.dart';
import 'package:jejaku/features/home/models/frame_audience.dart';
import 'package:jejaku/features/remote_frames/models/remote_frame.dart';
import 'package:jejaku/features/remote_frames/services/remote_frame_mapper.dart';

RemoteFrame _frame({String? frameStyle}) => RemoteFrame(
      id: 'remote-1',
      ownerId: 'someone-else',
      latitude: -6.2,
      longitude: 106.8,
      audience: FrameAudience.public,
      distanceMeters: 12,
      moderationStatus: 'approved',
      frameStyle: frameStyle,
    );

void main() {
  test("another person's frame is drawn in the look its owner chose", () {
    final known = builtInFrameLooks.last.id;
    final memory = RemoteFrameMapper.toAnchorMemory(_frame(frameStyle: known));

    expect(memory.frameLookId, known);
    expect(frameLookById(memory.frameLookId).id, known);
  });

  test('a frame without a look uses the default look', () {
    final memory = RemoteFrameMapper.toAnchorMemory(_frame());

    expect(memory.frameLookId, defaultFrameLookId);
  });

  test('a look this build does not know still draws, as the classic look', () {
    final memory = RemoteFrameMapper.toAnchorMemory(
      _frame(frameStyle: 'ext.acme.neon-glass'),
    );

    // The id is kept (a newer build may know it); rendering falls back.
    expect(memory.frameLookId, 'ext.acme.neon-glass');
    expect(frameLookById(memory.frameLookId).id, defaultFrameLookId);
    expect(memory.frameColorValue, isNull);
  });
}
