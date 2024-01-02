import 'dart:convert';
import 'dart:io';

import 'package:lib5/constants.dart';
import 'package:lib5/lib5.dart';

typedef UploadFileFunction = Future<CID> Function(File file);
typedef UploadMetadataFunction = Future<CID> Function(MediaMetadata metadata);

class MediaUploadTask {
  final bool transcode = false;
  final String name;
  final String artist;
  final String description;
  final File videoFile;
  final File thumbnailImageFile;

  final UploadFileFunction uploadFile;
  final UploadMetadataFunction uploadMetadata;

  final Function runFFProbe;
  MediaUploadTask({
    required this.name,
    required this.artist,
    required this.description,
    required this.videoFile,
    required this.thumbnailImageFile,

    /// ~
    required this.uploadFile,
    required this.uploadMetadata,
    required this.runFFProbe,
  });

  Future<CID> execute() async {
    final mf = await processFile(videoFile);

    final thumbnailMediaFormat = await processThumbnailFile(thumbnailImageFile);

    final media = MediaMetadata(
      name: name,
      details: MediaMetadataDetails(
          {metadataMediaDetailsDuration: (videoDuration! * 1000).round()}),
      parents: [],
      mediaTypes: {
        'video': [mf],
        "text": [
          MediaFormat(
            subtype: 'plain',
            role: 'description',
            value: utf8.encode(description),
          ),
          /* MediaFormat(
            subtype: 'plain',
            role: 'summary',
            value: utf8.encode(
              '''Join…''',
            ),
          ), */
        ],
        'image': [thumbnailMediaFormat]
      },
      extraMetadata: ExtraMetadata({
        // "licenses": ["CC-BY-3.0"],
        // metadataExtensionCategories: ["Tech"],
        //metadataExtensionTags: ["s5"],
        metadataExtensionTimestamp: DateTime.now().millisecondsSinceEpoch,
        metadataExtensionBasicMediaMetadata: {
          "title": name,
          "artist": artist,
        },
        metadataExtensionViewTypes: ["video", "audio"],
        metadataExtensionSourceUris: ['Original Content'],
      }),
    );
    // TODO serializeMediaMetadata should not be asnyc
    final cid = await uploadMetadata(media);
    final mediaCID = CID(cidTypeMetadataMedia, cid.hash);
    return mediaCID;
  }

  double? videoDuration;

  Future<MediaFormat> processThumbnailFile(File file) async {
    final cid = await uploadFile(file);

    // TODO Extract thumbnail metadata correctly

    return MediaFormat(
      cid: cid,
      subtype: "jpeg",
      role: "thumbnail",
      ext: "jpg",
      height: 720,
      width: 1280,
    );
  }

  Future<MediaFormat> processFile(File file) async {
    final args = [
      '-v',
      'quiet',
      '-print_format',
      'json',
      '-show_format',
      '-show_streams',
      file.path,
    ];

    final res = await runFFProbe(args);
    final metadata = jsonDecode(res.stdout);

    String formatName = metadata['format']['format_name'];
    if (formatName == 'mov,mp4,m4a,3gp,3g2,mj2') {
      formatName = 'mp4';
    }
    videoDuration = double.parse(metadata['format']['duration']);

    final videoStream = metadata['streams'].firstWhere(
      (s) => s['codec_type'] == 'video',
    );
    final audioStream = metadata['streams'].firstWhere(
      (s) => s['codec_type'] == 'audio',
    );

    final cid = await uploadFile(file);

    return MediaFormat(
      cid: cid,
      subtype: formatName,
      ext: file.path.split('.').last,
      height: videoStream['height'],
      width: videoStream['width'],
      // TODO yuv420p, see AV1 example
      fps: (int.parse(videoStream['nb_frames']) /
              double.parse(videoStream['duration']))
          .round(),
      bitrate: int.parse(metadata['format']['bit_rate']),
      vcodec: videoStream['codec_tag_string'],
      acodec: audioStream['codec_tag_string'],
      asr: int.parse(audioStream['sample_rate']),
      audioChannels: audioStream['channels'],
    );
  }
}
