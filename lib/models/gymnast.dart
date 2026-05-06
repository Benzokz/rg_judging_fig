class Gymnast {
  final String id;
  final String fullName;
  final String school;
  final String region;
  final String? photoUrl;

  Gymnast({
    required this.id,
    required this.fullName,
    required this.school,
    required this.region,
    this.photoUrl,
  });

  factory Gymnast.fromMap(Map<String, dynamic> map, String id) {
    return Gymnast(
      id: id,
      fullName: map['fullName'] ?? '',
      school: map['school'] ?? '',
      region: map['region'] ?? '',
      photoUrl: map['photoUrl'],
    );
  }
}
