import 'scenario_content.dart';

/// Scenario version summary for history list
class ScenarioVersionSummary {
  final String id;
  final int version;
  final String userPrompt;
  final DateTime createdAt;

  const ScenarioVersionSummary({
    required this.id,
    required this.version,
    required this.userPrompt,
    required this.createdAt,
  });

  factory ScenarioVersionSummary.fromJson(Map<String, dynamic> json) {
    return ScenarioVersionSummary(
      id: json['id'] as String,
      version: (json['version'] as num).toInt(),
      userPrompt: json['user_prompt'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'version': version,
      'user_prompt': userPrompt,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Complete scenario version with content
class ScenarioVersion {
  final String id;
  final int version;
  final ScenarioContent content;
  final DateTime createdAt;
  final List<String>? validationErrors;

  const ScenarioVersion({
    required this.id,
    required this.version,
    required this.content,
    required this.createdAt,
    this.validationErrors,
  });

  factory ScenarioVersion.fromJson(Map<String, dynamic> json) {
    return ScenarioVersion(
      id: json['id'] as String,
      version: (json['version'] as num).toInt(),
      content: ScenarioContent.fromJson(json['content'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['created_at'] as String),
      validationErrors: (json['validation_errors'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'version': version,
      'content': content.toJson(),
      'created_at': createdAt.toIso8601String(),
      if (validationErrors != null) 'validation_errors': validationErrors,
    };
  }
}

/// Scenario entity
class Scenario {
  final String id;
  final String title;
  final String status;
  final DateTime createdAt;
  final String? currentVersionId;
  final ScenarioVersion? currentVersion;

  const Scenario({
    required this.id,
    required this.title,
    required this.status,
    required this.createdAt,
    this.currentVersionId,
    this.currentVersion,
  });

  factory Scenario.fromJson(Map<String, dynamic> json) {
    return Scenario(
      id: json['id'] as String,
      title: json['title'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      currentVersionId: json['current_version_id'] as String?,
      currentVersion: json['current_version'] != null
          ? ScenarioVersion.fromJson(json['current_version'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      if (currentVersionId != null) 'current_version_id': currentVersionId,
      if (currentVersion != null) 'current_version': currentVersion!.toJson(),
    };
  }
}

/// Request to create a new scenario
class CreateScenarioRequest {
  final String description;

  const CreateScenarioRequest({
    required this.description,
  });

  factory CreateScenarioRequest.fromJson(Map<String, dynamic> json) {
    return CreateScenarioRequest(
      description: json['description'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'description': description,
    };
  }
}

/// Request to refine an existing scenario
class RefineScenarioRequest {
  final String prompt;

  const RefineScenarioRequest({
    required this.prompt,
  });

  factory RefineScenarioRequest.fromJson(Map<String, dynamic> json) {
    return RefineScenarioRequest(
      prompt: json['prompt'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'prompt': prompt,
    };
  }
}
