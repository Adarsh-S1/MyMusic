import 'package:isar/isar.dart';

part 'playlist_model.g.dart';

@collection
class PlaylistModel {
  Id id = Isar.autoIncrement;

  late String name;
  
  late DateTime dateCreated;

  List<String> songVideoIds = [];
}
