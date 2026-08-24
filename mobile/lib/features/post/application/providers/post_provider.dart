import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/post_repository.dart';

final postRepositoryProvider =
    Provider((ref) => PostRepository());