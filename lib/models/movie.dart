class DoubanSubject {
  final String id;
  final String title;
  final String rate;
  final String cover;
  final String? url;
  final String? year;
  final String? description;

  DoubanSubject({
    required this.id,
    required this.title,
    required this.rate,
    required this.cover,
    this.url,
    this.year,
    this.description,
  });

  factory DoubanSubject.fromJson(Map<String, dynamic> json) {
    return DoubanSubject(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      rate: json['rate']?.toString() ?? json['rating']?['value']?.toString() ?? '0.0',
      cover: json['cover'] ?? json['pic']?['normal'] ?? json['pic']?['large'] ?? '',
      url: json['url'],
      year: json['year'],
      description: json['description'] ?? json['intro'],
    );
  }
}
