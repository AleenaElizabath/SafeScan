class Farmer {
  final String? id;
  final String name;
  final String location;
  final String cropType;
  final String soilType;
  final String pesticidesUsed;
  final String season;

  Farmer({
    this.id,
    required this.name,
    required this.location,
    required this.cropType,
    required this.soilType,
    required this.pesticidesUsed,
    required this.season,
  });
}
