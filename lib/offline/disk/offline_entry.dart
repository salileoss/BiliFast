import 'package:bili_core/api.dart' show DashStream;
import 'package:flutter/foundation.dart';

import '../offline_models.dart';
import 'offline_files.dart';

/// One part as its folder keeps it (`entry.json`): the item, the ceiling it was asked at, the streams it downloads
/// (addresses blank) and how much of its danmaku is saved. Files are named relative to the part's folder, whose
/// absolute path changes with every update of the app.
@immutable
final class OfflineEntry {
  const OfflineEntry({
    required this.item,
    this.ceiling,
    this.video,
    this.audio,
    this.videoTotal = 0,
    this.audioTotal = 0,
    this.danmakuSegments = 0,
    this.danmakuSaved = 0,
    this.ownerMid,
    this.ownerKnown = false,
  });

  static const version = 1;

  /// The item, with [OfflineItem.coverFile] and [OfflineItem.faceFile] absolute for this launch.
  final OfflineItem item;

  /// The 缓存 sheet's quality; null for the highest the account gets.
  final int? ceiling;
  final int? ownerMid;
  /// Also true for a guest download; false only for entries predating account ownership.
  final bool ownerKnown;
  final DashStream? video;
  final DashStream? audio;
  final int videoTotal;
  final int audioTotal;

  /// How many 6-minute segments the danmaku has (0 until counted), and how many of them, from the first, are saved.
  final int danmakuSegments;
  final int danmakuSaved;

  int get cid => item.cid;
  bool get danmakuComplete => danmakuSegments > 0 && danmakuSaved >= danmakuSegments;

  OfflineEntry copyWith({
    OfflineItem? item,
    DashStream? video,
    DashStream? audio,
    int? videoTotal,
    int? audioTotal,
    int? danmakuSegments,
    int? danmakuSaved,
    int? ownerMid,
    bool? ownerKnown,
  }) => OfflineEntry(
    item: item ?? this.item,
    ceiling: ceiling,
    ownerMid: ownerMid ?? this.ownerMid,
    ownerKnown: ownerKnown ?? this.ownerKnown,
    video: video ?? this.video,
    audio: audio ?? this.audio,
    videoTotal: videoTotal ?? this.videoTotal,
    audioTotal: audioTotal ?? this.audioTotal,
    danmakuSegments: danmakuSegments ?? this.danmakuSegments,
    danmakuSaved: danmakuSaved ?? this.danmakuSaved,
  );

  Map<String, Object?> toJson() => {
    'version': version,
    'request': item.request.toJson(),
    'state': item.state.name,
    'failure': ?item.failure?.name,
    'addedAt': item.addedAt.millisecondsSinceEpoch,
    'ceiling': ?ceiling,
    'ownerMid': ?ownerMid,
    'ownerKnown': ownerKnown,
    'quality': item.quality,
    'qualityName': item.qualityName,
    'vipOnly': item.vipOnly,
    'bytes': item.bytes,
    'totalBytes': item.totalBytes,
    'videoTotal': videoTotal,
    'audioTotal': audioTotal,
    'position': item.position,
    'cover': ?(item.coverFile == null ? null : OfflineFiles.coverName),
    'face': ?(item.faceFile == null ? null : OfflineFiles.faceName),
    'video': ?video?.toJson(),
    'audio': ?audio?.toJson(),
    'danmaku': {'segments': danmakuSegments, 'saved': danmakuSaved},
  };

  /// [files] names the part's folder this launch; null when [json] isn't an entry.
  static OfflineEntry? fromJson(Object? json, OfflineFiles files) {
    if (json is! Map) return null;
    final request = OfflineRequest.fromJson(json['request']);
    final state = _named(json['state'], OfflineState.values);
    final addedAt = json['addedAt'];
    if (request == null || state == null || addedAt is! int) return null;
    final cid = request.cid;
    final danmaku = json['danmaku'];
    return OfflineEntry(
      item: OfflineItem(
        request: request,
        state: state,
        failure: _named(json['failure'], OfflineFailure.values),
        addedAt: DateTime.fromMillisecondsSinceEpoch(addedAt),
        quality: _int(json['quality']),
        qualityName: json['qualityName'] is String ? json['qualityName'] as String : '',
        vipOnly: json['vipOnly'] == true,
        bytes: _int(json['bytes']),
        totalBytes: _int(json['totalBytes']),
        position: json['position'] is num ? (json['position'] as num).toDouble() : 0,
        coverFile: json['cover'] is String ? files.cover(cid) : null,
        faceFile: json['face'] is String ? files.face(cid) : null,
      ),
      ceiling: json['ceiling'] is int ? json['ceiling'] as int : null,
      ownerMid: json['ownerMid'] is int && (json['ownerMid'] as int) > 0 ? json['ownerMid'] as int : null,
      ownerKnown: json['ownerKnown'] == true,
      video: _stream(json['video']),
      audio: _stream(json['audio']),
      videoTotal: _int(json['videoTotal']),
      audioTotal: _int(json['audioTotal']),
      danmakuSegments: danmaku is Map ? _int(danmaku['segments']) : 0,
      danmakuSaved: danmaku is Map ? _int(danmaku['saved']) : 0,
    );
  }

  static int _int(Object? value) => value is int ? value : 0;

  static T? _named<T extends Enum>(Object? value, List<T> values) =>
      value is String ? values.where((candidate) => candidate.name == value).firstOrNull : null;

  static DashStream? _stream(Object? json) {
    if (json is! Map) return null;
    try {
      return DashStream.fromJson(json.cast<String, Object?>());
    } on Object {
      return null;
    }
  }
}
