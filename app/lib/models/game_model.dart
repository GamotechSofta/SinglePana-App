class GameModel {
  const GameModel({
    required this.id,
    required this.gameCode,
    required this.name,
    required this.image,
  });

  final String id;
  final String gameCode;
  final String name;
  final String image;

  factory GameModel.fromJson(Map<String, dynamic> json) {
    return GameModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      gameCode: (json['gameCode'] ?? '').toString(),
      name: (json['name'] ?? 'Unnamed Game').toString(),
      image: (json['image'] ?? '').toString(),
    );
  }
}
