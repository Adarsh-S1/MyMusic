import 'package:isar/isar.dart';

part 'song_model.g.dart';

@collection
class SongModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String videoId;

  late String title;
  String? artist;
  
  late String localAudioPath;
  late String localThumbnailPath;
  late int durationMillis;
  late DateTime dateAdded;
}
