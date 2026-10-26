class GistProfile {
  const GistProfile({
    required this.id,
    required this.name,
    required this.githubUsername,
    this.bio = '',
    this.avatarUrl = '',
  });

  final String id;
  final String name;
  final String githubUsername;
  final String bio;
  final String avatarUrl;

  factory GistProfile.fromJson(Map<String, Object?> json) => GistProfile(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    githubUsername: json['githubUsername']?.toString() ?? '',
    bio: json['bio']?.toString() ?? '',
    avatarUrl: json['avatarUrl']?.toString() ?? '',
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'githubUsername': githubUsername,
    'bio': bio,
    'avatarUrl': avatarUrl,
  };
}

class GithubUser {
  const GithubUser({
    required this.login,
    this.name,
    this.avatarUrl = '',
    this.bio,
  });

  final String login;
  final String? name;
  final String avatarUrl;
  final String? bio;

  factory GithubUser.fromJson(Map<String, Object?> json) => GithubUser(
    login: json['login']?.toString() ?? '',
    name: json['name']?.toString(),
    avatarUrl: json['avatar_url']?.toString() ?? '',
    bio: json['bio']?.toString(),
  );
}

class LocalGist {
  const LocalGist({
    required this.id,
    this.description = '',
    this.files = const {},
    this.isPublic = false,
    this.htmlUrl = '',
    this.createdAt,
    this.updatedAt,
    this.tags = const [],
    this.isBookmarked = false,
    this.isDraft = false,
    this.bookmarkOrder = 0,
    this.owner,
  });

  final String id;
  final String description;
  final Map<String, GistFile> files;
  final bool isPublic;
  final String htmlUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<String> tags;
  final bool isBookmarked;
  final bool isDraft;
  final int bookmarkOrder;
  final GistOwner? owner;

  GistFile? get firstFile => files.values.isEmpty ? null : files.values.first;

  factory LocalGist.fromJson(
    Map<String, Object?> json, {
    List<String> tags = const [],
    bool? isBookmarked,
  }) {
    final rawFiles = json['files'];
    final parsedFiles = <String, GistFile>{};
    if (rawFiles is Map) {
      for (final entry in rawFiles.entries) {
        if (entry.value is Map) {
          final file = GistFile.fromJson(
            Map<String, Object?>.from(entry.value as Map),
            fallbackFilename: entry.key.toString(),
          );
          parsedFiles[entry.key.toString()] = file;
        }
      }
    }

    final rawTags = json['tags'];
    final savedTags = rawTags is List
        ? rawTags.map((tag) => tag.toString()).toList()
        : tags;

    return LocalGist(
      id: json['id']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      files: parsedFiles,
      isPublic: json['public'] == true,
      htmlUrl: json['html_url']?.toString() ?? '',
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      tags: savedTags,
      isBookmarked: isBookmarked ?? json['isBookmarked'] == true,
      isDraft: json['isDraft'] == true,
      bookmarkOrder: (json['bookmarkOrder'] as num?)?.toInt() ?? 0,
      owner: json['owner'] is Map
          ? GistOwner.fromJson(Map<String, Object?>.from(json['owner'] as Map))
          : null,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'description': description,
    'files': files.map((key, value) => MapEntry(key, value.toJson())),
    'public': isPublic,
    'html_url': htmlUrl,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'tags': tags,
    'isBookmarked': isBookmarked,
    'isDraft': isDraft,
    'bookmarkOrder': bookmarkOrder,
    'owner': owner?.toJson(),
  };

  LocalGist copyWith({
    bool? isDraft,
    String? description,
    Map<String, GistFile>? files,
    bool? isPublic,
    String? htmlUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tags,
    bool? isBookmarked,
    int? bookmarkOrder,
    GistOwner? owner,
  }) {
    return LocalGist(
      id: id,
      isDraft: isDraft ?? this.isDraft,
      description: description ?? this.description,
      files: files ?? this.files,
      isPublic: isPublic ?? this.isPublic,
      htmlUrl: htmlUrl ?? this.htmlUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      bookmarkOrder: bookmarkOrder ?? this.bookmarkOrder,
      owner: owner ?? this.owner,
    );
  }
}

class GistOwner {
  const GistOwner({
    required this.login,
    this.avatarUrl = '',
    this.htmlUrl = '',
  });

  final String login;
  final String avatarUrl;
  final String htmlUrl;

  factory GistOwner.fromJson(Map<String, Object?> json) => GistOwner(
    login: json['login']?.toString() ?? '',
    avatarUrl: json['avatar_url']?.toString() ?? '',
    htmlUrl: json['html_url']?.toString() ?? '',
  );

  Map<String, Object?> toJson() => {
    'login': login,
    'avatar_url': avatarUrl,
    'html_url': htmlUrl,
  };
}

class GistFile {
  const GistFile({
    required this.filename,
    this.type = '',
    this.language = '',
    this.rawUrl = '',
    this.content = '',
    this.truncated = false,
  });

  final String filename;
  final String type;
  final String language;
  final String rawUrl;
  final String content;
  final bool truncated;

  factory GistFile.fromJson(
    Map<String, Object?> json, {
    required String fallbackFilename,
  }) {
    return GistFile(
      filename: json['filename']?.toString() ?? fallbackFilename,
      type: json['type']?.toString() ?? '',
      language: json['language']?.toString() ?? '',
      rawUrl: json['raw_url']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      truncated: json['truncated'] == true,
    );
  }

  Map<String, Object?> toJson() => {
    'filename': filename,
    'type': type,
    'language': language,
    'raw_url': rawUrl,
    'content': content,
    'truncated': truncated,
  };
}

class ImportedGistInput {
  const ImportedGistInput({
    required this.description,
    required this.isPublic,
    required this.files,
  });

  final String description;
  final bool isPublic;
  final Map<String, GistFile> files;
}

DateTime? _parseDate(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
