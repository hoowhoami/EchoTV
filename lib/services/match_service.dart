import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/movie.dart';
import '../models/site.dart';
import 'cms_service.dart';
import 'config_service.dart';

final matchServiceProvider = Provider((ref) => MatchService(ref));

class MatchService {
  final Ref _ref;

  MatchService(this._ref);

  Future<VideoDetail?> findMatch(DoubanSubject subject) async {
    final cmsService = _ref.read(cmsServiceProvider);
    final configService = _ref.read(configServiceProvider);
    final sites = await configService.getSites();
    
    // Try each site until a match is found
    for (var site in sites) {
      final results = await cmsService.search(site, subject.title);
      if (results.isNotEmpty) {
        // Simple matching logic: find the one with the same title
        final match = results.firstWhere(
          (r) => r.title.contains(subject.title) || subject.title.contains(r.title),
          orElse: () => results.first,
        );
        
        // Fetch full detail for the matched item
        return await cmsService.getDetail(site, match.id);
      }
    }
    return null;
  }
}