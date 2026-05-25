import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KazeRunnerApp());
}

enum Goal { weightLoss, maintain, gainMass }

extension GoalX on Goal {
  String get label {
    switch (this) {
      case Goal.weightLoss:
        return 'Похудение';
      case Goal.maintain:
        return 'Поддержание формы';
      case Goal.gainMass:
        return 'Набор массы';
    }
  }

  String labelFor(AppLanguage language) {
    if (language == AppLanguage.en) {
      return switch (this) {
        Goal.weightLoss => 'Weight loss',
        Goal.maintain => 'Maintenance',
        Goal.gainMass => 'Muscle gain',
      };
    }
    return label;
  }
}

enum Gender { male, female }

extension GenderX on Gender {
  String get label {
    switch (this) {
      case Gender.male:
        return 'Мужской';
      case Gender.female:
        return 'Женский';
    }
  }

  String labelFor(AppLanguage language) {
    if (language == AppLanguage.en) {
      return switch (this) {
        Gender.male => 'Male',
        Gender.female => 'Female',
      };
    }
    return label;
  }
}

enum WorkoutEmotion { great, normal, tired, exhausted }

extension WorkoutEmotionX on WorkoutEmotion {
  String get emoji {
    switch (this) {
      case WorkoutEmotion.great:
        return '😄';
      case WorkoutEmotion.normal:
        return '🙂';
      case WorkoutEmotion.tired:
        return '😐';
      case WorkoutEmotion.exhausted:
        return '🥵';
    }
  }

  String get label {
    switch (this) {
      case WorkoutEmotion.great:
        return 'Отлично';
      case WorkoutEmotion.normal:
        return 'Нормально';
      case WorkoutEmotion.tired:
        return 'Устал';
      case WorkoutEmotion.exhausted:
        return 'Очень тяжело';
    }
  }

  String labelFor(AppLanguage language) {
    if (language == AppLanguage.en) {
      return switch (this) {
        WorkoutEmotion.great => 'Great',
        WorkoutEmotion.normal => 'Normal',
        WorkoutEmotion.tired => 'Tired',
        WorkoutEmotion.exhausted => 'Very hard',
      };
    }
    return label;
  }
}

enum AppLanguage { ru, en }

AppLanguage? _activeAppLanguage;

extension AppLanguageX on AppLanguage {
  String get label {
    switch (this) {
      case AppLanguage.ru:
        return 'Русский';
      case AppLanguage.en:
        return 'English';
    }
  }

  static AppLanguage fromDevice() {
    final String code = ui.PlatformDispatcher.instance.locale.languageCode;
    return code.toLowerCase().startsWith('ru')
        ? AppLanguage.ru
        : AppLanguage.en;
  }
}

enum UnitSystem { metric, imperial }

extension UnitSystemX on UnitSystem {
  String get label {
    switch (this) {
      case UnitSystem.metric:
        return 'Европейская: см, кг, км';
      case UnitSystem.imperial:
        return 'USA: ft/in, lb, mi';
    }
  }

  String labelFor(AppLanguage language) {
    if (language == AppLanguage.en) {
      return switch (this) {
        UnitSystem.metric => 'Metric: cm, kg, km',
        UnitSystem.imperial => 'USA: ft/in, lb, mi',
      };
    }
    return label;
  }
}

class _AppLanguageScope extends InheritedWidget {
  const _AppLanguageScope({required this.language, required super.child});

  final AppLanguage language;

  static AppLanguage of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_AppLanguageScope>()
            ?.language ??
        _activeAppLanguage ??
        AppLanguageX.fromDevice();
  }

  @override
  bool updateShouldNotify(_AppLanguageScope oldWidget) {
    return oldWidget.language != language;
  }
}

extension _L10nContext on BuildContext {
  AppLanguage get lang => _AppLanguageScope.of(this);

  String tr(String ru, String en) {
    return lang == AppLanguage.en ? en : ru;
  }
}

class AppSettings {
  const AppSettings({required this.language, required this.unitSystem});

  final AppLanguage language;
  final UnitSystem unitSystem;

  factory AppSettings.defaults() {
    return AppSettings(
      language: AppLanguageX.fromDevice(),
      unitSystem: UnitSystem.metric,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'language': language.name,
      'unitSystem': unitSystem.name,
    };
  }

  factory AppSettings.fromJson(Object? source) {
    final Map<String, dynamic>? json = source is Map
        ? Map<String, dynamic>.from(source)
        : null;
    if (json == null) return AppSettings.defaults();
    final String languageName =
        json['language'] as String? ?? AppLanguageX.fromDevice().name;
    final String unitSystemName =
        json['unitSystem'] as String? ?? UnitSystem.metric.name;
    return AppSettings(
      language:
          AppLanguage.values.where((AppLanguage value) {
            return value.name == languageName;
          }).firstOrNull ??
          AppLanguageX.fromDevice(),
      unitSystem:
          UnitSystem.values.where((UnitSystem value) {
            return value.name == unitSystemName;
          }).firstOrNull ??
          UnitSystem.metric,
    );
  }

  AppSettings copyWith({AppLanguage? language, UnitSystem? unitSystem}) {
    return AppSettings(
      language: language ?? this.language,
      unitSystem: unitSystem ?? this.unitSystem,
    );
  }
}

class UserProfile {
  const UserProfile({
    required this.username,
    required this.heightCm,
    required this.weightKg,
    required this.gender,
    required this.age,
    required this.goal,
    required this.workoutsPerWeek,
    this.avatarPath,
  });

  final String username;
  final double heightCm;
  final double weightKg;
  final Gender gender;
  final int age;
  final Goal goal;
  final int workoutsPerWeek;
  final String? avatarPath;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'username': username,
      'heightCm': heightCm,
      'weightKg': weightKg,
      'gender': gender.name,
      'age': age,
      'goal': goal.name,
      'workoutsPerWeek': workoutsPerWeek,
      'avatarPath': avatarPath,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      username: json['username'] as String,
      heightCm: (json['heightCm'] as num).toDouble(),
      weightKg: (json['weightKg'] as num).toDouble(),
      gender: Gender.values.byName(json['gender'] as String),
      age: json['age'] as int,
      goal: Goal.values.byName(json['goal'] as String),
      workoutsPerWeek: json['workoutsPerWeek'] as int,
      avatarPath: json['avatarPath'] as String?,
    );
  }

  UserProfile copyWith({
    String? username,
    double? heightCm,
    double? weightKg,
    Gender? gender,
    int? age,
    Goal? goal,
    int? workoutsPerWeek,
    String? avatarPath,
    bool clearAvatar = false,
  }) {
    return UserProfile(
      username: username ?? this.username,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      goal: goal ?? this.goal,
      workoutsPerWeek: workoutsPerWeek ?? this.workoutsPerWeek,
      avatarPath: clearAvatar ? null : (avatarPath ?? this.avatarPath),
    );
  }
}

class RoutePoint {
  const RoutePoint(this.lat, this.lng);

  final double lat;
  final double lng;

  Map<String, dynamic> toJson() => <String, dynamic>{'lat': lat, 'lng': lng};

  factory RoutePoint.fromJson(Map<String, dynamic> json) {
    return RoutePoint(
      (json['lat'] as num).toDouble(),
      (json['lng'] as num).toDouble(),
    );
  }
}

class RunEntry {
  const RunEntry({
    required this.startedAtIso,
    required this.durationSeconds,
    required this.distanceKm,
    required this.route,
  });

  final String startedAtIso;
  final int durationSeconds;
  final double distanceKm;
  final List<RoutePoint> route;

  DateTime get startedAt => DateTime.parse(startedAtIso);

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'startedAtIso': startedAtIso,
      'durationSeconds': durationSeconds,
      'distanceKm': distanceKm,
      'route': route.map((RoutePoint e) => e.toJson()).toList(),
    };
  }

  factory RunEntry.fromJson(Map<String, dynamic> json) {
    return RunEntry(
      startedAtIso: json['startedAtIso'] as String,
      durationSeconds: json['durationSeconds'] as int,
      distanceKm: (json['distanceKm'] as num).toDouble(),
      route: (json['route'] as List<dynamic>)
          .map((dynamic e) => RoutePoint.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class FoodEntry {
  const FoodEntry({
    required this.id,
    required this.dateIso,
    required this.name,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.waterMl,
  });

  final String id;
  final String dateIso;
  final String name;
  final double calories;
  final double protein;
  final double fat;
  final double carbs;
  final int waterMl;

  DateTime get date => DateTime.parse(dateIso);

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'dateIso': dateIso,
      'name': name,
      'calories': calories,
      'protein': protein,
      'fat': fat,
      'carbs': carbs,
      'waterMl': waterMl,
    };
  }

  factory FoodEntry.fromJson(Map<String, dynamic> json) {
    return FoodEntry(
      id: json['id'] as String,
      dateIso: json['dateIso'] as String,
      name: json['name'] as String,
      calories: (json['calories'] as num).toDouble(),
      protein: (json['protein'] as num).toDouble(),
      fat: (json['fat'] as num).toDouble(),
      carbs: (json['carbs'] as num).toDouble(),
      waterMl: json['waterMl'] as int? ?? 0,
    );
  }
}

class _FoodVisionResult {
  const _FoodVisionResult({
    required this.foodLabel,
    required this.confidence,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
  });

  final String foodLabel;
  final double confidence;
  final double calories;
  final double protein;
  final double fat;
  final double carbs;

  _FoodVisionResult copyWith({
    String? foodLabel,
    double? confidence,
    double? calories,
    double? protein,
    double? fat,
    double? carbs,
  }) {
    return _FoodVisionResult(
      foodLabel: foodLabel ?? this.foodLabel,
      confidence: confidence ?? this.confidence,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      fat: fat ?? this.fat,
      carbs: carbs ?? this.carbs,
    );
  }
}

class PlannedExercise {
  const PlannedExercise({
    required this.name,
    required this.sets,
    required this.reps,
  });

  final String name;
  final int sets;
  final int reps;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'name': name, 'sets': sets, 'reps': reps};
  }

  factory PlannedExercise.fromJson(Map<String, dynamic> json) {
    return PlannedExercise(
      name: json['name'] as String,
      sets: json['sets'] as int? ?? 3,
      reps: json['reps'] as int? ?? 10,
    );
  }

  PlannedExercise copyWith({int? sets, int? reps}) {
    return PlannedExercise(
      name: name,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
    );
  }
}

class PlannedWorkout {
  const PlannedWorkout({
    required this.id,
    required this.createdAtIso,
    required this.plannedDateIso,
    required this.exercises,
  });

  final String id;
  final String createdAtIso;
  final String plannedDateIso;
  final List<PlannedExercise> exercises;

  DateTime get createdAt => DateTime.parse(createdAtIso);
  DateTime get plannedDate => DateTime.parse(plannedDateIso);

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'createdAtIso': createdAtIso,
      'plannedDateIso': plannedDateIso,
      'exercises': exercises.map((PlannedExercise e) => e.toJson()).toList(),
    };
  }

  factory PlannedWorkout.fromJson(Map<String, dynamic> json) {
    return PlannedWorkout(
      id:
          json['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      createdAtIso: json['createdAtIso'] as String,
      plannedDateIso:
          json['plannedDateIso'] as String? ?? json['createdAtIso'] as String,
      exercises: (json['exercises'] as List<dynamic>)
          .map(
            (dynamic e) => PlannedExercise.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  PlannedWorkout copyWith({
    List<PlannedExercise>? exercises,
    String? plannedDateIso,
  }) {
    return PlannedWorkout(
      id: id,
      createdAtIso: createdAtIso,
      plannedDateIso: plannedDateIso ?? this.plannedDateIso,
      exercises: exercises ?? this.exercises,
    );
  }
}

class CompletedWorkout {
  const CompletedWorkout({
    required this.completedAtIso,
    required this.durationSeconds,
    required this.emotion,
    required this.exercises,
  });

  final String completedAtIso;
  final int durationSeconds;
  final WorkoutEmotion emotion;
  final List<PlannedExercise> exercises;

  DateTime get completedAt => DateTime.parse(completedAtIso);

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'completedAtIso': completedAtIso,
      'durationSeconds': durationSeconds,
      'emotion': emotion.name,
      'exercises': exercises.map((PlannedExercise e) => e.toJson()).toList(),
    };
  }

  factory CompletedWorkout.fromJson(Map<String, dynamic> json) {
    return CompletedWorkout(
      completedAtIso: json['completedAtIso'] as String,
      durationSeconds: json['durationSeconds'] as int,
      emotion: WorkoutEmotion.values.byName(json['emotion'] as String),
      exercises: (json['exercises'] as List<dynamic>)
          .map(
            (dynamic e) => PlannedExercise.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class AssistantMessage {
  const AssistantMessage({
    required this.role,
    required this.text,
    required this.createdAtIso,
  });

  final String role;
  final String text;
  final String createdAtIso;

  DateTime get createdAt => DateTime.parse(createdAtIso);

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'role': role,
      'text': text,
      'createdAtIso': createdAtIso,
    };
  }

  factory AssistantMessage.fromJson(Map<String, dynamic> json) {
    return AssistantMessage(
      role: json['role'] as String? ?? 'assistant',
      text: json['text'] as String? ?? '',
      createdAtIso:
          json['createdAtIso'] as String? ?? DateTime.now().toIso8601String(),
    );
  }
}

class AssistantConversation {
  const AssistantConversation({
    required this.id,
    required this.title,
    required this.createdAtIso,
    required this.updatedAtIso,
    required this.messages,
  });

  final String id;
  final String title;
  final String createdAtIso;
  final String updatedAtIso;
  final List<AssistantMessage> messages;

  DateTime get createdAt => DateTime.parse(createdAtIso);
  DateTime get updatedAt => DateTime.parse(updatedAtIso);

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'createdAtIso': createdAtIso,
      'updatedAtIso': updatedAtIso,
      'messages': messages.map((AssistantMessage e) => e.toJson()).toList(),
    };
  }

  factory AssistantConversation.fromJson(Map<String, dynamic> json) {
    return AssistantConversation(
      id:
          json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? 'Чат',
      createdAtIso:
          json['createdAtIso'] as String? ?? DateTime.now().toIso8601String(),
      updatedAtIso:
          json['updatedAtIso'] as String? ?? DateTime.now().toIso8601String(),
      messages: (json['messages'] as List<dynamic>? ?? <dynamic>[])
          .map(
            (dynamic e) => AssistantMessage.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  AssistantConversation copyWith({
    String? title,
    String? updatedAtIso,
    List<AssistantMessage>? messages,
  }) {
    return AssistantConversation(
      id: id,
      title: title ?? this.title,
      createdAtIso: createdAtIso,
      updatedAtIso: updatedAtIso ?? this.updatedAtIso,
      messages: messages ?? this.messages,
    );
  }
}

class AppData {
  const AppData({
    required this.profile,
    required this.settings,
    required this.totalWorkouts,
    required this.workoutDays,
    required this.runDays,
    required this.runs,
    required this.foodEntries,
    required this.plannedWorkouts,
    required this.rememberedExerciseSets,
    required this.completedWorkouts,
    required this.assistantConversations,
  });

  final UserProfile profile;
  final AppSettings settings;
  final int totalWorkouts;
  final List<String> workoutDays;
  final List<String> runDays;
  final List<RunEntry> runs;
  final List<FoodEntry> foodEntries;
  final List<PlannedWorkout> plannedWorkouts;
  final Map<String, int> rememberedExerciseSets;
  final List<CompletedWorkout> completedWorkouts;
  final List<AssistantConversation> assistantConversations;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'profile': profile.toJson(),
      'settings': settings.toJson(),
      'totalWorkouts': totalWorkouts,
      'workoutDays': workoutDays,
      'runDays': runDays,
      'runs': runs.map((RunEntry e) => e.toJson()).toList(),
      'foodEntries': foodEntries.map((FoodEntry e) => e.toJson()).toList(),
      'plannedWorkouts': plannedWorkouts
          .map((PlannedWorkout e) => e.toJson())
          .toList(),
      'rememberedExerciseSets': rememberedExerciseSets,
      'completedWorkouts': completedWorkouts
          .map((CompletedWorkout e) => e.toJson())
          .toList(),
      'assistantConversations': assistantConversations
          .map((AssistantConversation e) => e.toJson())
          .toList(),
    };
  }

  factory AppData.fromJson(Map<String, dynamic> json) {
    final List<PlannedWorkout> planned =
        (json['plannedWorkouts'] as List<dynamic>? ?? <dynamic>[])
            .map(
              (dynamic e) => PlannedWorkout.fromJson(e as Map<String, dynamic>),
            )
            .toList();
    if (planned.isEmpty && json['activeWorkout'] != null) {
      planned.add(
        PlannedWorkout.fromJson(
          json['activeWorkout'] as Map<String, dynamic>,
        ).copyWith(plannedDateIso: DateTime.now().toIso8601String()),
      );
    }
    return AppData(
      profile: UserProfile.fromJson(json['profile'] as Map<String, dynamic>),
      settings: AppSettings.fromJson(json['settings']),
      totalWorkouts: json['totalWorkouts'] as int? ?? 0,
      workoutDays:
          (json['workoutDays'] as List<dynamic>? ??
                  json['trainingDays'] as List<dynamic>? ??
                  <dynamic>[])
              .map((dynamic e) => e as String)
              .toList(),
      runDays: (json['runDays'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic e) => e as String)
          .toList(),
      runs: (json['runs'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic e) => RunEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      foodEntries: (json['foodEntries'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic e) => FoodEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      plannedWorkouts: planned,
      rememberedExerciseSets:
          (json['rememberedExerciseSets'] as Map<String, dynamic>? ??
                  <String, dynamic>{})
              .map((String key, dynamic value) => MapEntry(key, value as int)),
      completedWorkouts:
          (json['completedWorkouts'] as List<dynamic>? ?? <dynamic>[])
              .map(
                (dynamic e) =>
                    CompletedWorkout.fromJson(e as Map<String, dynamic>),
              )
              .toList(),
      assistantConversations:
          (json['assistantConversations'] as List<dynamic>? ?? <dynamic>[])
              .map(
                (dynamic e) =>
                    AssistantConversation.fromJson(e as Map<String, dynamic>),
              )
              .toList(),
    );
  }

  AppData copyWith({
    UserProfile? profile,
    AppSettings? settings,
    int? totalWorkouts,
    List<String>? workoutDays,
    List<String>? runDays,
    List<RunEntry>? runs,
    List<FoodEntry>? foodEntries,
    List<PlannedWorkout>? plannedWorkouts,
    Map<String, int>? rememberedExerciseSets,
    List<CompletedWorkout>? completedWorkouts,
    List<AssistantConversation>? assistantConversations,
  }) {
    return AppData(
      profile: profile ?? this.profile,
      settings: settings ?? this.settings,
      totalWorkouts: totalWorkouts ?? this.totalWorkouts,
      workoutDays: workoutDays ?? this.workoutDays,
      runDays: runDays ?? this.runDays,
      runs: runs ?? this.runs,
      foodEntries: foodEntries ?? this.foodEntries,
      plannedWorkouts: plannedWorkouts ?? this.plannedWorkouts,
      rememberedExerciseSets:
          rememberedExerciseSets ?? this.rememberedExerciseSets,
      completedWorkouts: completedWorkouts ?? this.completedWorkouts,
      assistantConversations:
          assistantConversations ?? this.assistantConversations,
    );
  }
}

class LocalAppStorage {
  static const String _key = 'local_user_profile';

  Future<AppData?> loadData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_key);
    if (raw == null) {
      return null;
    }
    final Map<String, dynamic> map = jsonDecode(raw) as Map<String, dynamic>;
    if (!map.containsKey('profile')) {
      final UserProfile oldProfile = UserProfile.fromJson(map);
      return AppData(
        profile: oldProfile,
        settings: AppSettings.defaults(),
        totalWorkouts: 0,
        workoutDays: <String>[],
        runDays: <String>[],
        runs: <RunEntry>[],
        foodEntries: <FoodEntry>[],
        plannedWorkouts: <PlannedWorkout>[],
        rememberedExerciseSets: <String, int>{},
        completedWorkouts: <CompletedWorkout>[],
        assistantConversations: <AssistantConversation>[],
      );
    }
    return AppData.fromJson(map);
  }

  Future<void> saveData(AppData data) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(data.toJson()));
  }

  Future<void> clearData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

class CloudAccountService {
  static const Duration retention = Duration(days: 30);
  static const int _schemaVersion = 1;
  static const String _collection = 'users';
  static const String _stateCollection = 'appState';
  static const String _stateDoc = 'current';

  bool _available = false;
  bool _googleSignInInitialized = false;

  bool get available => _available;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  User? get currentUser => _available ? _auth.currentUser : null;
  bool get signedIn => currentUser != null;

  Future<void> initialize() async {
    if (Platform.environment['FLUTTER_TEST'] == 'true') {
      _available = false;
      return;
    }
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp().timeout(const Duration(seconds: 14));
      }
      _available = true;
    } catch (_) {
      _available = false;
    }
  }

  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      if (error.code == 'email-already-in-use') {
        return _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
      rethrow;
    }
  }

  Future<UserCredential> signInWithGoogle() {
    if (kIsWeb) {
      final GoogleAuthProvider provider = GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile');
      return _auth.signInWithPopup(provider);
    }
    return _signInWithNativeGoogle();
  }

  Future<UserCredential> signInWithApple() {
    return _auth.signInWithProvider(AppleAuthProvider());
  }

  Future<UserCredential> _signInWithNativeGoogle() async {
    await _ensureGoogleSignInInitialized();
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw FirebaseAuthException(
        code: 'google-sign-in-not-supported',
        message:
            'Google Sign-In недоступен на этой платформе. Используй Android, iOS, macOS или Web.',
      );
    }
    final GoogleSignInAccount googleUser = await GoogleSignIn.instance
        .authenticate();
    final GoogleSignInAuthentication googleAuth = googleUser.authentication;
    final String? idToken = googleAuth.idToken;
    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'missing-google-id-token',
        message:
            'Google не вернул ID token. Проверь SHA-1/SHA-256 в Firebase Console и актуальный google-services.json.',
      );
    }
    final OAuthCredential credential = GoogleAuthProvider.credential(
      idToken: idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignInInitialized) return;
    await GoogleSignIn.instance.initialize();
    _googleSignInInitialized = true;
  }

  Future<AppData?> loadRemoteData() async {
    final User? user = currentUser;
    if (!_available || user == null) return null;
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _stateRef(
      user,
    ).get();
    final Map<String, dynamic>? document = snapshot.data();
    if (document == null) return null;
    final Timestamp? expiresAt = document['expiresAt'] as Timestamp?;
    if (expiresAt != null && expiresAt.toDate().isBefore(DateTime.now())) {
      await snapshot.reference.delete();
      return null;
    }
    final Object? rawData = document['data'];
    if (rawData is! Map) return null;
    return AppData.fromJson(Map<String, dynamic>.from(rawData));
  }

  Future<void> saveRemoteData(AppData data) async {
    final User? user = currentUser;
    if (!_available || user == null) return;
    final DateTime expiresAt = DateTime.now().add(retention);
    final WriteBatch batch = _firestore.batch();
    batch.set(_userRef(user), <String, dynamic>{
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName ?? data.profile.username,
      'providerIds': user.providerData
          .map((UserInfo provider) => provider.providerId)
          .toList(),
      'profile': data.profile.toJson(),
      'settings': data.settings.toJson(),
      'summary': _summaryFor(data),
      'achievements': _achievementSnapshotsFor(data),
      'schemaVersion': _schemaVersion,
      'retentionDays': retention.inDays,
      'lastSyncedAt': FieldValue.serverTimestamp(),
      'lastSyncedAtIso': DateTime.now().toUtc().toIso8601String(),
      'authCreatedAt': user.metadata.creationTime == null
          ? null
          : Timestamp.fromDate(user.metadata.creationTime!),
      'lastSignInAt': user.metadata.lastSignInTime == null
          ? null
          : Timestamp.fromDate(user.metadata.lastSignInTime!),
    }, SetOptions(merge: true));
    batch.set(_stateRef(user), <String, dynamic>{
      'ownerUid': user.uid,
      'schemaVersion': _schemaVersion,
      'data': data.toJson(),
      'summary': _summaryFor(data),
      'achievements': _achievementSnapshotsFor(data),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedAtIso': DateTime.now().toUtc().toIso8601String(),
      'expiresAt': Timestamp.fromDate(expiresAt),
    }, SetOptions(merge: true));
    for (final FoodEntry entry in data.foodEntries) {
      batch.set(
        _userRef(user).collection('foodEntries').doc(entry.id),
        _foodEntryDocument(entry, user.uid),
        SetOptions(merge: true),
      );
    }
    for (final PlannedWorkout workout in data.plannedWorkouts) {
      batch.set(
        _userRef(user).collection('plannedWorkouts').doc(workout.id),
        _plannedWorkoutDocument(workout, user.uid),
        SetOptions(merge: true),
      );
    }
    for (final CompletedWorkout workout in data.completedWorkouts) {
      final String id = _safeDocId(workout.completedAtIso);
      batch.set(
        _userRef(user).collection('completedWorkouts').doc(id),
        _completedWorkoutDocument(workout, data.profile, user.uid),
        SetOptions(merge: true),
      );
    }
    for (final RunEntry run in data.runs) {
      final String id = _safeDocId(run.startedAtIso);
      batch.set(
        _userRef(user).collection('runs').doc(id),
        _runEntryDocument(run, user.uid),
        SetOptions(merge: true),
      );
    }
    for (final AssistantConversation conversation
        in data.assistantConversations) {
      batch.set(
        _userRef(
          user,
        ).collection('assistantConversations').doc(conversation.id),
        <String, dynamic>{
          ...conversation.toJson(),
          'ownerUid': user.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    for (final Map<String, dynamic> achievement in _achievementSnapshotsFor(
      data,
    )) {
      batch.set(
        _userRef(
          user,
        ).collection('achievements').doc(achievement['id'] as String),
        <String, dynamic>{
          ...achievement,
          'ownerUid': user.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  Future<void> deleteRemoteData() async {
    final User? user = currentUser;
    if (!_available || user == null) return;
    for (final String collection in <String>[
      _stateCollection,
      'foodEntries',
      'plannedWorkouts',
      'completedWorkouts',
      'runs',
      'assistantConversations',
      'achievements',
    ]) {
      await _deleteUserSubcollection(user, collection);
    }
    final WriteBatch batch = _firestore.batch();
    batch.delete(_userRef(user));
    await batch.commit();
  }

  Future<void> signOut() async {
    if (!_available) return;
    await _auth.signOut();
  }

  DocumentReference<Map<String, dynamic>> _userRef(User user) {
    return _firestore.collection(_collection).doc(user.uid);
  }

  DocumentReference<Map<String, dynamic>> _stateRef(User user) {
    return _userRef(user).collection(_stateCollection).doc(_stateDoc);
  }

  Map<String, dynamic> _summaryFor(AppData data) {
    final double totalRunKm = data.runs.fold<double>(
      0,
      (double sum, RunEntry run) => sum + run.distanceKm,
    );
    final double totalFoodCalories = data.foodEntries.fold<double>(
      0,
      (double sum, FoodEntry entry) => sum + entry.calories,
    );
    return <String, dynamic>{
      'username': data.profile.username,
      'language': data.settings.language.name,
      'unitSystem': data.settings.unitSystem.name,
      'goal': data.profile.goal.name,
      'gender': data.profile.gender.name,
      'heightCm': data.profile.heightCm,
      'weightKg': data.profile.weightKg,
      'age': data.profile.age,
      'workoutsPerWeek': data.profile.workoutsPerWeek,
      'totalWorkouts': data.totalWorkouts,
      'plannedWorkoutsCount': data.plannedWorkouts.length,
      'completedWorkoutsCount': data.completedWorkouts.length,
      'runsCount': data.runs.length,
      'totalRunKm': totalRunKm,
      'foodEntriesCount': data.foodEntries.length,
      'totalFoodCalories': totalFoodCalories,
      'assistantConversationsCount': data.assistantConversations.length,
      'achievementsUnlocked': _achievementSnapshotsFor(
        data,
      ).where((Map<String, dynamic> item) => item['done'] == true).length,
    };
  }

  Map<String, dynamic> _foodEntryDocument(FoodEntry entry, String ownerUid) {
    return <String, dynamic>{
      ...entry.toJson(),
      'ownerUid': ownerUid,
      'dateKey': _dateKey(entry.date),
      'macros': <String, dynamic>{
        'calories': entry.calories,
        'protein': entry.protein,
        'fat': entry.fat,
        'carbs': entry.carbs,
        'waterMl': entry.waterMl,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> _plannedWorkoutDocument(
    PlannedWorkout workout,
    String ownerUid,
  ) {
    return <String, dynamic>{
      ...workout.toJson(),
      'ownerUid': ownerUid,
      'plannedDateKey': _dateKey(workout.plannedDate),
      ..._exerciseStats(workout.exercises),
      'exercisesDetailed': workout.exercises
          .map(_exerciseDocument)
          .toList(growable: false),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> _completedWorkoutDocument(
    CompletedWorkout workout,
    UserProfile profile,
    String ownerUid,
  ) {
    return <String, dynamic>{
      ...workout.toJson(),
      'ownerUid': ownerUid,
      'completedDateKey': _dateKey(workout.completedAt),
      'durationMinutes': workout.durationSeconds / 60,
      'emotionLabelRu': workout.emotion.labelFor(AppLanguage.ru),
      'emotionLabelEn': workout.emotion.labelFor(AppLanguage.en),
      'caloriesEstimate': _estimatedWorkoutCalories(workout, profile),
      ..._exerciseStats(workout.exercises),
      'exercisesDetailed': workout.exercises
          .map(_exerciseDocument)
          .toList(growable: false),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> _runEntryDocument(RunEntry run, String ownerUid) {
    final double paceSecondsPerKm = run.distanceKm <= 0
        ? 0
        : run.durationSeconds / run.distanceKm;
    return <String, dynamic>{
      ...run.toJson(),
      'ownerUid': ownerUid,
      'dateKey': _dateKey(run.startedAt),
      'durationMinutes': run.durationSeconds / 60,
      'distanceMeters': run.distanceKm * 1000,
      'paceSecondsPerKm': paceSecondsPerKm,
      'routePointCount': run.route.length,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> _exerciseStats(List<PlannedExercise> exercises) {
    return <String, dynamic>{
      'exerciseCount': exercises.length,
      'totalSets': exercises.fold<int>(
        0,
        (int sum, PlannedExercise exercise) => sum + exercise.sets,
      ),
      'totalReps': exercises.fold<int>(
        0,
        (int sum, PlannedExercise exercise) =>
            sum + exercise.sets * exercise.reps,
      ),
    };
  }

  Map<String, dynamic> _exerciseDocument(PlannedExercise exercise) {
    return <String, dynamic>{
      ...exercise.toJson(),
      'nameEn': _exerciseNameForLanguage(exercise.name, AppLanguage.en),
      'totalReps': exercise.sets * exercise.reps,
    };
  }

  String _dateKey(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _safeDocId(String value) {
    return value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '-');
  }

  Future<void> _deleteUserSubcollection(User user, String collection) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _userRef(
      user,
    ).collection(collection).get();
    if (snapshot.docs.isEmpty) return;
    final WriteBatch batch = _firestore.batch();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}

class KazeRunnerApp extends StatelessWidget {
  const KazeRunnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF74B6F6),
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kaze Runner',
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const <Locale>[Locale('ru'), Locale('en')],
      theme: ThemeData(
        colorScheme: scheme,
        fontFamily: 'Nunito',
        fontFamilyFallback: const <String>[
          'SF Pro Display',
          'Inter',
          'Roboto',
          'Arial',
        ],
        useMaterial3: true,
      ),
      home: const RootPage(),
    );
  }
}

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  final LocalAppStorage _storage = LocalAppStorage();
  final CloudAccountService _cloud = CloudAccountService();
  AppData? _appData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    await _cloud.initialize();
    AppData? data = await _cloud.loadRemoteData();
    data ??= await _storage.loadData();
    if (data != null && _cloud.signedIn) {
      await _cloud.saveRemoteData(data);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _appData = data;
      _loading = false;
    });
  }

  Future<void> _createProfile(
    UserProfile profile,
    AppSettings settings,
    String email,
    String password,
  ) async {
    if (_cloud.available) {
      await _cloud.registerWithEmail(email: email, password: password);
      final AppData? remoteData = await _cloud.loadRemoteData();
      if (remoteData != null) {
        await _storage.saveData(remoteData);
        if (!mounted) return;
        setState(() => _appData = remoteData);
        return;
      }
    }
    await _createDataFromProfile(profile, settings: settings);
  }

  Future<void> _createDataFromProfile(
    UserProfile profile, {
    AppSettings? settings,
  }) async {
    final AppData data = AppData(
      profile: profile,
      settings: settings ?? AppSettings.defaults(),
      totalWorkouts: 0,
      workoutDays: <String>[],
      runDays: <String>[],
      runs: <RunEntry>[],
      foodEntries: <FoodEntry>[],
      plannedWorkouts: <PlannedWorkout>[],
      rememberedExerciseSets: <String, int>{},
      completedWorkouts: <CompletedWorkout>[],
      assistantConversations: <AssistantConversation>[],
    );
    await _storage.saveData(data);
    await _cloud.saveRemoteData(data);
    if (!mounted) {
      return;
    }
    setState(() {
      _appData = data;
    });
  }

  Future<void> _signInWithProvider(
    Future<UserCredential> Function() signIn,
    UserProfile? fallbackProfile,
    AppSettings fallbackSettings,
  ) async {
    if (!_cloud.available) {
      await _cloud.initialize();
    }
    if (!_cloud.available) {
      throw FirebaseException(
        plugin: 'firebase_core',
        message:
            'Firebase не настроен. Добавь конфиги проекта для Android/iOS/Web.',
      );
    }
    await signIn();
    final AppData? remoteData = await _cloud.loadRemoteData();
    if (remoteData != null) {
      await _storage.saveData(remoteData);
      if (!mounted) return;
      setState(() => _appData = remoteData);
      return;
    }
    if (fallbackProfile == null) {
      throw FirebaseException(
        plugin: 'firebase_auth',
        message: 'Сначала заполни профиль, чтобы создать облачную запись.',
      );
    }
    await _createDataFromProfile(fallbackProfile, settings: fallbackSettings);
  }

  Future<void> _saveAppData(AppData data) async {
    await _storage.saveData(data);
    await _cloud.saveRemoteData(data);
    if (!mounted) {
      return;
    }
    setState(() {
      _appData = data;
    });
  }

  Future<void> _deleteData() async {
    await _cloud.deleteRemoteData();
    await _cloud.signOut();
    await _storage.clearData();
    if (!mounted) {
      return;
    }
    setState(() {
      _appData = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_appData == null) {
      return AccountCreationScreen(
        firebaseAvailable: _cloud.available,
        onSubmit: _createProfile,
        onGoogleAuth: (UserProfile? profile, AppSettings settings) =>
            _signInWithProvider(_cloud.signInWithGoogle, profile, settings),
        onAppleAuth: (UserProfile? profile, AppSettings settings) =>
            _signInWithProvider(_cloud.signInWithApple, profile, settings),
      );
    }
    return MainTabsScreen(
      appData: _appData!,
      onSaveData: _saveAppData,
      onDeleteProfile: _deleteData,
    );
  }
}

class AccountCreationScreen extends StatefulWidget {
  const AccountCreationScreen({
    super.key,
    required this.firebaseAvailable,
    required this.onSubmit,
    required this.onGoogleAuth,
    required this.onAppleAuth,
  });

  final bool firebaseAvailable;
  final Future<void> Function(
    UserProfile profile,
    AppSettings settings,
    String email,
    String password,
  )
  onSubmit;
  final Future<void> Function(UserProfile? profile, AppSettings settings)
  onGoogleAuth;
  final Future<void> Function(UserProfile? profile, AppSettings settings)
  onAppleAuth;

  @override
  State<AccountCreationScreen> createState() => _AccountCreationScreenState();
}

class _AccountCreationScreenState extends State<AccountCreationScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _heightCtrl = TextEditingController();
  final TextEditingController _weightCtrl = TextEditingController();
  final TextEditingController _ageCtrl = TextEditingController();
  final TextEditingController _workoutsCtrl = TextEditingController(text: '3');
  late final AnimationController _introPulseCtrl;
  late final Animation<double> _introScale;

  Gender _selectedGender = Gender.male;
  Goal _selectedGoal = Goal.maintain;
  late AppLanguage _selectedLanguage;
  UnitSystem _selectedUnitSystem = UnitSystem.metric;
  bool _showIntro = true;
  bool _obscurePassword = true;
  bool _authInProgress = false;
  static final RegExp _decimalRegex = RegExp(r'^\d*([.,]\d*)?$');

  @override
  void initState() {
    super.initState();
    _selectedLanguage = AppLanguageX.fromDevice();
    _introPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    )..repeat(reverse: true);
    _introScale = Tween<double>(begin: 0.94, end: 1.04).animate(
      CurvedAnimation(parent: _introPulseCtrl, curve: Curves.easeInOut),
    );
    Timer(const Duration(milliseconds: 2700), () {
      if (!mounted) return;
      setState(() => _showIntro = false);
      _introPulseCtrl.stop();
    });
  }

  @override
  void dispose() {
    _introPulseCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _ageCtrl.dispose();
    _workoutsCtrl.dispose();
    super.dispose();
  }

  UserProfile _profileFromForm() {
    final double heightCm = _parseHeightCm(_heightCtrl.text.trim()) ?? 0;
    final double weightKg = _parseWeightKg(_weightCtrl.text.trim()) ?? 0;
    return UserProfile(
      username: _usernameCtrl.text.trim(),
      heightCm: heightCm,
      weightKg: weightKg,
      gender: _selectedGender,
      age: int.parse(_ageCtrl.text.trim()),
      goal: _selectedGoal,
      workoutsPerWeek: int.parse(_workoutsCtrl.text.trim()),
    );
  }

  AppSettings _settingsFromForm() {
    return AppSettings(
      language: _selectedLanguage,
      unitSystem: _selectedUnitSystem,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await _runAuthAction(
      () => widget.onSubmit(
        _profileFromForm(),
        _settingsFromForm(),
        _emailCtrl.text.trim(),
        _passwordCtrl.text.trim(),
      ),
    );
  }

  Future<void> _socialAuth(
    Future<void> Function(UserProfile? profile, AppSettings settings) action,
  ) async {
    final UserProfile? profile = _profileFromProfileFields();
    await _runAuthAction(() => action(profile, _settingsFromForm()));
  }

  UserProfile? _profileFromProfileFields() {
    final String username = _usernameCtrl.text.trim();
    final double? height = _parseHeightCm(_heightCtrl.text.trim());
    final double? weight = _parseWeightKg(_weightCtrl.text.trim());
    final int? age = int.tryParse(_ageCtrl.text.trim());
    final int? workouts = int.tryParse(_workoutsCtrl.text.trim());
    if (username.isEmpty ||
        height == null ||
        height <= 0 ||
        weight == null ||
        weight <= 0 ||
        age == null ||
        age < 10 ||
        age > 100 ||
        workouts == null ||
        workouts < 1 ||
        workouts > 7) {
      return null;
    }
    return UserProfile(
      username: username,
      heightCm: height,
      weightKg: weight,
      gender: _selectedGender,
      age: age,
      goal: _selectedGoal,
      workoutsPerWeek: workouts,
    );
  }

  double? _parseHeightCm(String raw) {
    if (_selectedUnitSystem == UnitSystem.metric) {
      return double.tryParse(raw.replaceAll(',', '.'));
    }
    final String normalized = raw
        .replaceAll('"', '')
        .replaceAll('ft', "'")
        .replaceAll('in', '')
        .replaceAll(',', '.')
        .trim();
    if (normalized.contains("'") || normalized.contains(' ')) {
      final List<String> parts = normalized
          .split(RegExp(r"['\s]+"))
          .where((String part) => part.isNotEmpty)
          .toList();
      final double? feet = parts.isEmpty ? null : double.tryParse(parts[0]);
      final double inches = parts.length > 1
          ? double.tryParse(parts[1]) ?? 0
          : 0;
      if (feet == null) return null;
      return (feet * 12 + inches) * 2.54;
    }
    final double? feet = double.tryParse(normalized);
    return feet == null ? null : feet * 30.48;
  }

  double? _parseWeightKg(String raw) {
    final double? value = double.tryParse(raw.replaceAll(',', '.'));
    if (value == null) return null;
    return _selectedUnitSystem == UnitSystem.metric ? value : value / 2.20462;
  }

  String get _heightLabel {
    return _selectedUnitSystem == UnitSystem.metric
        ? _tr('Рост (см)', 'Height (cm)')
        : "Height (ft/in, e.g. 6'2)";
  }

  String get _weightLabel {
    return _selectedUnitSystem == UnitSystem.metric
        ? _tr('Вес (кг)', 'Weight (kg)')
        : 'Weight (lb)';
  }

  String _tr(String ru, String en) {
    return _selectedLanguage == AppLanguage.en ? en : ru;
  }

  Future<void> _runAuthAction(Future<void> Function() action) async {
    if (_authInProgress) return;
    setState(() => _authInProgress = true);
    try {
      await action();
    } on FirebaseAuthException catch (error) {
      _showMessage(_authErrorText(error));
    } on FirebaseException catch (error) {
      _showMessage(
        error.message ??
            _tr(
              'Firebase пока не настроен.',
              'Firebase is not configured yet.',
            ),
      );
    } catch (error) {
      _showMessage(
        _tr('Не удалось войти: $error', 'Could not sign in: $error'),
      );
    } finally {
      if (mounted) setState(() => _authInProgress = false);
    }
  }

  String? _required(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return _tr('Введите $fieldName', 'Enter $fieldName');
    }
    return null;
  }

  String? _emailValidator(String? value) {
    final String? base = _required(value, 'email');
    if (base != null) return base;
    final String text = value!.trim();
    return text.contains('@') && text.contains('.')
        ? null
        : _tr('Введите корректный email', 'Enter a valid email');
  }

  String _authErrorText(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return _tr('Проверь email.', 'Check your email.');
      case 'wrong-password':
      case 'invalid-credential':
        return _tr(
          'Неверный email или пароль.',
          'Incorrect email or password.',
        );
      case 'weak-password':
        return _tr('Пароль слишком простой.', 'Password is too weak.');
      case 'account-exists-with-different-credential':
        return _tr(
          'Этот email уже привязан к другому способу входа.',
          'This email is already linked to another sign-in method.',
        );
      case 'network-request-failed':
        return _tr('Нет соединения с Firebase.', 'No Firebase connection.');
    }
    return error.message ?? _tr('Не удалось войти.', 'Could not sign in.');
  }

  TextStyle get _inputTextStyle => const TextStyle(
    color: Color(0xFF102A43),
    fontSize: 17,
    fontWeight: FontWeight.w900,
    height: 1.16,
  );

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final Color accent = const Color(0xFF438ED8);
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: const Color(0xFF3D668F).withValues(alpha: 0.86),
        fontWeight: FontWeight.w600,
      ),
      floatingLabelStyle: const TextStyle(
        color: Color(0xFF2376C4),
        fontWeight: FontWeight.w800,
      ),
      prefixIcon: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: accent.withValues(alpha: 0.18)),
          ),
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, size: 20, color: accent),
          ),
        ),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 58, minHeight: 54),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.86),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.78)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(
          color: const Color(0xFF98C9F8).withValues(alpha: 0.56),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFF2F8DE4), width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: Colors.red.shade300),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.7),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    _activeAppLanguage = _selectedLanguage;
    return _AppLanguageScope(
      language: _selectedLanguage,
      child: Localizations.override(
        context: context,
        locale: Locale(_selectedLanguage.name),
        child: Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: Colors.white,
          body: Stack(
            children: [
              const Positioned.fill(child: _RegistrationBackground()),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 650),
                child: _showIntro ? _buildIntro(context) : _buildForm(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntro(BuildContext context) {
    return Center(
      key: const ValueKey<String>('intro'),
      child: ScaleTransition(
        scale: _introScale,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Text(
            _tr(
              'Твой ритм. Твоя сила. Твой прогресс.',
              'Your rhythm. Your strength. Your progress.',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: const Color(0xFF2F72B8),
              fontWeight: FontWeight.w800,
              height: 1.18,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return SafeArea(
      key: const ValueKey<String>('form'),
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 38, 18, 24),
          children: [
            Text(
              _tr('Настрой свой ритм', 'Set Your Rhythm'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: const Color(0xFF0F477C),
                fontFamily: 'Nunito',
                fontSize: 30,
                fontWeight: FontWeight.w900,
                height: 1.04,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _tr(
                'Профиль нужен для норм калорий, БЖУ, тренировок и синхронизации данных в облаке.',
                'Your profile powers calories, macros, workouts, and cloud sync.',
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF193F64),
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
                height: 1.32,
              ),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _usernameCtrl,
              style: _inputTextStyle,
              textCapitalization: TextCapitalization.words,
              decoration: _fieldDecoration(
                label: _tr('Имя пользователя', 'Name'),
                icon: Icons.person_outline,
              ),
              validator: (String? value) =>
                  _required(value, _tr('имя пользователя', 'name')),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              style: _inputTextStyle,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: _fieldDecoration(
                label: 'Email',
                icon: Icons.alternate_email,
              ),
              validator: _emailValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordCtrl,
              style: _inputTextStyle,
              obscureText: _obscurePassword,
              decoration: _fieldDecoration(
                label: _tr('Пароль', 'Password'),
                icon: Icons.lock_outline,
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  tooltip: _obscurePassword
                      ? _tr('Показать пароль', 'Show password')
                      : _tr('Скрыть пароль', 'Hide password'),
                ),
              ),
              validator: (String? value) {
                final String? base = _required(
                  value,
                  _tr('пароль', 'password'),
                );
                if (base != null) return base;
                return value!.trim().length < 6
                    ? _tr(
                        'Пароль должен быть от 6 символов',
                        'Password must be at least 6 characters',
                      )
                    : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _heightCtrl,
              style: _inputTextStyle,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r"[0-9.,' ]")),
              ],
              decoration: _fieldDecoration(
                label: _heightLabel,
                icon: Icons.height,
              ),
              validator: (String? value) {
                final String? base = _required(value, _tr('рост', 'height'));
                if (base != null) return base;
                final double? parsed = _parseHeightCm(value!.trim());
                return (parsed == null || parsed < 100 || parsed > 250)
                    ? _tr(
                        'Укажи рост от 100 до 250 см или корректные ft/in',
                        'Enter 100-250 cm or valid ft/in',
                      )
                    : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _weightCtrl,
              style: _inputTextStyle,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(_decimalRegex),
              ],
              decoration: _fieldDecoration(
                label: _weightLabel,
                icon: Icons.monitor_weight_outlined,
              ),
              validator: (String? value) {
                final String? base = _required(value, _tr('вес', 'weight'));
                if (base != null) return base;
                final double? parsed = _parseWeightKg(value!.trim());
                return (parsed == null || parsed < 30 || parsed > 300)
                    ? _tr(
                        'Укажи вес от 30 до 300 кг или корректные lb',
                        'Enter 30-300 kg or valid lb',
                      )
                    : null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Gender>(
              initialValue: _selectedGender,
              decoration: _fieldDecoration(
                label: _tr('Пол', 'Gender'),
                icon: Icons.wc_outlined,
              ),
              items: Gender.values
                  .map(
                    (Gender g) => DropdownMenuItem(
                      value: g,
                      child: Text(g.labelFor(_selectedLanguage)),
                    ),
                  )
                  .toList(),
              onChanged: (Gender? value) {
                if (value != null) setState(() => _selectedGender = value);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ageCtrl,
              style: _inputTextStyle,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _fieldDecoration(
                label: _tr('Возраст', 'Age'),
                icon: Icons.cake_outlined,
              ),
              validator: (String? value) {
                final String? base = _required(value, _tr('возраст', 'age'));
                if (base != null) return base;
                final int? parsed = int.tryParse(value!.trim());
                return (parsed == null || parsed < 10 || parsed > 120)
                    ? _tr(
                        'Возраст должен быть от 10 до 120',
                        'Age must be between 10 and 120',
                      )
                    : null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Goal>(
              initialValue: _selectedGoal,
              decoration: _fieldDecoration(
                label: _tr('Цель', 'Goal'),
                icon: Icons.flag_outlined,
              ),
              items: Goal.values
                  .map(
                    (Goal g) => DropdownMenuItem(
                      value: g,
                      child: Text(g.labelFor(_selectedLanguage)),
                    ),
                  )
                  .toList(),
              onChanged: (Goal? value) {
                if (value != null) setState(() => _selectedGoal = value);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<UnitSystem>(
              initialValue: _selectedUnitSystem,
              decoration: _fieldDecoration(
                label: _tr('Система единиц', 'Unit system'),
                icon: Icons.straighten,
              ),
              items: UnitSystem.values
                  .map(
                    (UnitSystem system) => DropdownMenuItem(
                      value: system,
                      child: Text(system.labelFor(_selectedLanguage)),
                    ),
                  )
                  .toList(),
              onChanged: (UnitSystem? value) {
                if (value != null) {
                  setState(() => _selectedUnitSystem = value);
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<AppLanguage>(
              initialValue: _selectedLanguage,
              decoration: _fieldDecoration(
                label: _tr('Язык', 'Language'),
                icon: Icons.language,
              ),
              items: AppLanguage.values
                  .map(
                    (AppLanguage language) => DropdownMenuItem(
                      value: language,
                      child: Text(language.label),
                    ),
                  )
                  .toList(),
              onChanged: (AppLanguage? value) {
                if (value != null) {
                  setState(() => _selectedLanguage = value);
                }
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _workoutsCtrl,
              style: _inputTextStyle,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _fieldDecoration(
                label: _tr(
                  'Тренировок в неделю (1-7)',
                  'Workouts per week (1-7)',
                ),
                icon: Icons.fitness_center_outlined,
              ),
              validator: (String? value) {
                final String? base = _required(
                  value,
                  _tr('число тренировок', 'number of workouts'),
                );
                if (base != null) return base;
                final int? parsed = int.tryParse(value!.trim());
                return (parsed == null || parsed < 1 || parsed > 7)
                    ? _tr('Введите число от 1 до 7', 'Enter 1 to 7')
                    : null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _authInProgress ? null : _submit,
              icon: _authInProgress
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_done_outlined),
              label: Text(_tr('Создать аккаунт', 'Create account')),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: Divider(color: Colors.blue.shade100)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    _tr('или войти через сервис', 'or sign in with'),
                    style: TextStyle(color: Colors.blueGrey.shade600),
                  ),
                ),
                Expanded(child: Divider(color: Colors.blue.shade100)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _SocialAuthButton(
                    label: 'Google',
                    background: Colors.white,
                    foreground: const Color(0xFF263238),
                    borderColor: Colors.lightBlue.shade100,
                    icon: const Text(
                      'G',
                      style: TextStyle(
                        color: Color(0xFF4285F4),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    onPressed: _authInProgress
                        ? null
                        : () => _socialAuth(widget.onGoogleAuth),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SocialAuthButton(
                    label: 'Apple',
                    background: const Color(0xFF111111),
                    foreground: Colors.white,
                    icon: const Icon(Icons.apple, size: 21),
                    onPressed: _authInProgress
                        ? null
                        : () => _socialAuth(widget.onAppleAuth),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              widget.firebaseAvailable
                  ? _tr(
                      'Данные сохраняются на устройстве и в Firebase на 30 дней после последнего обновления.',
                      'Data is saved on this device and in Firebase for 30 days after the last update.',
                    )
                  : _tr(
                      'Firebase ещё не настроен: добавь конфиги проекта, и синхронизация включится автоматически.',
                      'Firebase is not configured yet: add project config files and sync will turn on automatically.',
                    ),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.blueGrey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialAuthButton extends StatelessWidget {
  const _SocialAuthButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.icon,
    required this.onPressed,
    this.borderColor,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Widget icon;
  final VoidCallback? onPressed;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          side: BorderSide(color: borderColor ?? background),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTheme(
              data: IconThemeData(color: foreground),
              child: DefaultTextStyle(
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                ),
                child: icon,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}

class _RegistrationBackground extends StatelessWidget {
  const _RegistrationBackground();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/registration_background.png',
      fit: BoxFit.cover,
      alignment: Alignment.center,
    );
  }
}

class _AssistantReminder {
  const _AssistantReminder({required this.title, required this.message});

  final String title;
  final String message;
}

class MainTabsScreen extends StatefulWidget {
  const MainTabsScreen({
    super.key,
    required this.appData,
    required this.onSaveData,
    required this.onDeleteProfile,
  });

  final AppData appData;
  final Future<void> Function(AppData data) onSaveData;
  final Future<void> Function() onDeleteProfile;

  @override
  State<MainTabsScreen> createState() => _MainTabsScreenState();
}

class _MainTabsScreenState extends State<MainTabsScreen> {
  int _selectedIndex = 0;
  bool _assistantReminderShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowAssistantReminder();
    });
  }

  String _dayKey(DateTime date) {
    final String mm = date.month.toString().padLeft(2, '0');
    final String dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }

  DateTime _dayStart(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  _AssistantReminder? _buildAssistantReminder() {
    final AppLanguage language = widget.appData.settings.language;
    String tr(String ru, String en) => language == AppLanguage.en ? en : ru;
    final DateTime now = DateTime.now();
    final DateTime today = _dayStart(now);
    final bool hasAnyActivity =
        widget.appData.plannedWorkouts.isNotEmpty ||
        widget.appData.completedWorkouts.isNotEmpty ||
        widget.appData.runs.isNotEmpty ||
        widget.appData.foodEntries.isNotEmpty;
    if (!hasAnyActivity) {
      return null;
    }
    final bool plannedToday = widget.appData.plannedWorkouts.any(
      (PlannedWorkout workout) => _sameCalendarDay(workout.plannedDate, today),
    );
    if (plannedToday) {
      return _AssistantReminder(
        title: tr('Kaze напоминает', 'Kaze Reminder'),
        message: tr(
          'Сегодня запланирована тренировка. Открой чат, если нужно адаптировать нагрузку.',
          'You have a workout planned today. Open chat if you want to adjust the load.',
        ),
      );
    }

    final List<FoodEntry> foods = List<FoodEntry>.from(
      widget.appData.foodEntries,
    )..sort((FoodEntry a, FoodEntry b) => b.date.compareTo(a.date));
    final bool ateToday = foods.any(
      (FoodEntry entry) => _sameCalendarDay(entry.date, today),
    );
    if (!ateToday && now.hour >= 12) {
      return _AssistantReminder(
        title: tr('Питание', 'Nutrition'),
        message: tr(
          'За сегодня еще нет приемов пищи. Kaze может быстро собрать рацион и БЖУ.',
          'No meals logged today yet. Kaze can quickly build a meal plan and macros.',
        ),
      );
    }

    final List<CompletedWorkout> workouts =
        List<CompletedWorkout>.from(widget.appData.completedWorkouts)..sort(
          (CompletedWorkout a, CompletedWorkout b) =>
              b.completedAt.compareTo(a.completedAt),
        );
    if (workouts.isEmpty ||
        now.difference(workouts.first.completedAt).inDays >= 5) {
      return _AssistantReminder(
        title: tr('Тренировка', 'Workout'),
        message: tr(
          'Давно не было завершенной тренировки. Kaze подберет мягкий старт под текущую усталость.',
          'No completed workouts for a while. Kaze can suggest a gentle start based on your fatigue.',
        ),
      );
    }
    return null;
  }

  Future<void> _maybeShowAssistantReminder() async {
    if (_assistantReminderShown || !mounted) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    final _AssistantReminder? reminder = _buildAssistantReminder();
    if (reminder == null) return;
    _assistantReminderShown = true;
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        final double dialogWidth = min(
          MediaQuery.sizeOf(context).width - 64,
          360,
        );
        return AlertDialog(
          contentPadding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
          content: SizedBox(
            width: dialogWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.asset(
                    _kazeAssetForVisual(
                      _KazeVisualState.reminder,
                      language: widget.appData.settings.language,
                    ),
                    height: 180,
                    width: dialogWidth,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  reminder.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(reminder.message, textAlign: TextAlign.center),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('Позже', 'Later')),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _openAssistantChat();
              },
              child: Text(context.tr('Открыть Kaze', 'Open Kaze')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveProfile(UserProfile profile) async {
    await widget.onSaveData(widget.appData.copyWith(profile: profile));
  }

  Future<void> _saveSettings(AppSettings settings) async {
    await widget.onSaveData(widget.appData.copyWith(settings: settings));
  }

  Future<void> _saveRun(RunEntry run) async {
    final List<RunEntry> runs = List<RunEntry>.from(widget.appData.runs)
      ..insert(0, run);
    final Set<String> days = widget.appData.runDays.toSet()
      ..add(_dayKey(run.startedAt));
    await widget.onSaveData(
      widget.appData.copyWith(
        runs: runs,
        totalWorkouts: widget.appData.totalWorkouts + 1,
        runDays: days.toList(),
      ),
    );
  }

  Future<void> _saveFoodEntries(List<FoodEntry> entries) async {
    await widget.onSaveData(widget.appData.copyWith(foodEntries: entries));
  }

  Future<void> _saveAssistantConversations(
    List<AssistantConversation> conversations,
  ) async {
    await widget.onSaveData(
      widget.appData.copyWith(assistantConversations: conversations),
    );
  }

  void _openAssistantIntro() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return _AssistantIntroSheet(
          onOpenChat: () {
            Navigator.pop(sheetContext);
            _openAssistantChat();
          },
          onOpenHistory: () {
            Navigator.pop(sheetContext);
            _openAssistantChat(showHistory: true);
          },
        );
      },
    );
  }

  void _openAssistantChat({bool showHistory = false}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return AssistantChatScreen(
            appData: widget.appData,
            showHistoryInitially: showHistory,
            onChanged: _saveAssistantConversations,
          );
        },
      ),
    );
  }

  DateTime _normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _scheduleWorkout(
    List<String> exerciseNames,
    DateTime date, {
    String? editingId,
    List<PlannedExercise>? exercises,
  }) async {
    final DateTime normalizedDate = _normalizeDate(date);
    final List<PlannedWorkout> planned = List<PlannedWorkout>.from(
      widget.appData.plannedWorkouts,
    );
    final bool duplicate = planned.any((PlannedWorkout p) {
      if (editingId != null && p.id == editingId) return false;
      return _sameDay(p.plannedDate, normalizedDate);
    });
    if (duplicate) {
      return;
    }
    final DateTime today = _normalizeDate(DateTime.now());
    final PlannedWorkout nextWorkout = PlannedWorkout(
      id: editingId ?? DateTime.now().microsecondsSinceEpoch.toString(),
      createdAtIso: DateTime.now().toIso8601String(),
      plannedDateIso: normalizedDate.toIso8601String(),
      exercises:
          exercises ??
          exerciseNames.map((String e) {
            final int rememberedSets =
                widget.appData.rememberedExerciseSets[e] ?? 3;
            return PlannedExercise(name: e, sets: rememberedSets, reps: 10);
          }).toList(),
    );
    final Map<String, int> remembered = Map<String, int>.from(
      widget.appData.rememberedExerciseSets,
    );
    for (final PlannedExercise exercise in nextWorkout.exercises) {
      remembered[exercise.name] = exercise.sets;
    }

    if (normalizedDate.isBefore(today)) {
      if (editingId != null) {
        planned.removeWhere((PlannedWorkout p) => p.id == editingId);
      }
      final List<CompletedWorkout> history = List<CompletedWorkout>.from(
        widget.appData.completedWorkouts,
      );
      history.insert(
        0,
        CompletedWorkout(
          completedAtIso: normalizedDate.toIso8601String(),
          durationSeconds: 60,
          emotion: WorkoutEmotion.normal,
          exercises: nextWorkout.exercises,
        ),
      );
      final Set<String> workoutDays = widget.appData.workoutDays.toSet()
        ..add(_dayKey(normalizedDate));
      await widget.onSaveData(
        widget.appData.copyWith(
          plannedWorkouts: planned,
          completedWorkouts: history,
          workoutDays: workoutDays.toList(),
          totalWorkouts: widget.appData.totalWorkouts + 1,
          rememberedExerciseSets: remembered,
        ),
      );
      return;
    }

    if (editingId == null) {
      planned.add(nextWorkout);
    } else {
      final int index = planned.indexWhere(
        (PlannedWorkout p) => p.id == editingId,
      );
      if (index >= 0) {
        planned[index] = nextWorkout;
      } else {
        planned.add(nextWorkout);
      }
    }
    await widget.onSaveData(
      widget.appData.copyWith(
        plannedWorkouts: planned,
        rememberedExerciseSets: remembered,
      ),
    );
  }

  Future<void> _deletePlannedWorkout(String id) async {
    final List<PlannedWorkout> planned = List<PlannedWorkout>.from(
      widget.appData.plannedWorkouts,
    )..removeWhere((PlannedWorkout p) => p.id == id);
    await widget.onSaveData(widget.appData.copyWith(plannedWorkouts: planned));
  }

  Future<void> _updatePlannedWorkout(PlannedWorkout workout) async {
    final List<PlannedWorkout> planned = List<PlannedWorkout>.from(
      widget.appData.plannedWorkouts,
    );
    final int index = planned.indexWhere(
      (PlannedWorkout p) => p.id == workout.id,
    );
    if (index >= 0) {
      planned[index] = workout;
      await widget.onSaveData(
        widget.appData.copyWith(plannedWorkouts: planned),
      );
    }
  }

  Future<void> _saveRememberedSets(Map<String, int> values) async {
    await widget.onSaveData(
      widget.appData.copyWith(rememberedExerciseSets: values),
    );
  }

  Future<void> _completeWorkout(
    PlannedWorkout planned,
    WorkoutEmotion emotion,
    int durationSeconds,
  ) async {
    if (!widget.appData.plannedWorkouts.any(
      (PlannedWorkout p) => p.id == planned.id,
    )) {
      return;
    }
    final DateTime now = DateTime.now();
    final int duration = max(1, durationSeconds);
    final CompletedWorkout completed = CompletedWorkout(
      completedAtIso: now.toIso8601String(),
      durationSeconds: duration,
      emotion: emotion,
      exercises: planned.exercises,
    );
    final List<CompletedWorkout> history = List<CompletedWorkout>.from(
      widget.appData.completedWorkouts,
    )..insert(0, completed);
    final List<PlannedWorkout> remaining = List<PlannedWorkout>.from(
      widget.appData.plannedWorkouts,
    )..removeWhere((PlannedWorkout p) => p.id == planned.id);
    final Set<String> days = widget.appData.workoutDays.toSet()
      ..add(_dayKey(now));
    await widget.onSaveData(
      widget.appData.copyWith(
        plannedWorkouts: remaining,
        completedWorkouts: history,
        totalWorkouts: widget.appData.totalWorkouts + 1,
        workoutDays: days.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLanguage language = widget.appData.settings.language;
    _activeAppLanguage = language;
    final Color sectionColor = _colorForIndex(_selectedIndex);
    final List<Widget> pages = [
      ActivityScreen(
        profile: widget.appData.profile,
        plannedWorkouts: widget.appData.plannedWorkouts,
        rememberedExerciseSets: widget.appData.rememberedExerciseSets,
        completedWorkouts: widget.appData.completedWorkouts,
        totalWorkouts: widget.appData.totalWorkouts,
        onScheduleWorkout: _scheduleWorkout,
        onUpdatePlannedWorkout: _updatePlannedWorkout,
        onDeletePlannedWorkout: _deletePlannedWorkout,
        onSaveRememberedSets: _saveRememberedSets,
        onCompleteWorkout: _completeWorkout,
      ),
      FoodScreen(
        profile: widget.appData.profile,
        entries: widget.appData.foodEntries,
        onChanged: _saveFoodEntries,
      ),
      RunScreen(
        profile: widget.appData.profile,
        runs: widget.appData.runs,
        onRunSaved: _saveRun,
      ),
      ProfileScreen(
        appData: widget.appData,
        onProfileUpdated: _saveProfile,
        onSettingsUpdated: _saveSettings,
        onDeleteProfile: widget.onDeleteProfile,
      ),
    ];
    return _AppLanguageScope(
      language: language,
      child: Localizations.override(
        context: context,
        locale: Locale(language.name),
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              _titleForIndex(_selectedIndex, language),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            foregroundColor: sectionColor,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
          ),
          body: IndexedStack(index: _selectedIndex, children: pages),
          floatingActionButton: _selectedIndex < 3
              ? _AssistantLauncherButton(onPressed: _openAssistantIntro)
              : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
          bottomNavigationBar: _ConnectedNavigationBar(
            selectedIndex: _selectedIndex,
            onSelected: (int index) => setState(() => _selectedIndex = index),
          ),
        ),
      ),
    );
  }

  Color _colorForIndex(int index) {
    return switch (index) {
      0 => const Color(0xFF2478E8),
      1 => const Color(0xFF05AFA8),
      2 => const Color(0xFF8C63F6),
      3 => const Color(0xFF17171C),
      _ => const Color(0xFF2478E8),
    };
  }

  String _titleForIndex(int index, AppLanguage language) {
    String tr(String ru, String en) => language == AppLanguage.en ? en : ru;
    switch (index) {
      case 0:
        return tr('Активность', 'Activity');
      case 1:
        return tr('Питание', 'Nutrition');
      case 2:
        return tr('Бег', 'Running');
      case 3:
        return tr('Профиль', 'Profile');
      default:
        return 'Kaze Runner';
    }
  }
}

class _AssistantLauncherButton extends StatelessWidget {
  const _AssistantLauncherButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            spreadRadius: -2,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipOval(
        child: Material(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: InkWell(
            onTap: onPressed,
            child: Ink(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Padding(
                padding: EdgeInsets.all(5),
                child: _KazeLogoMark(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectedNavigationBar extends StatelessWidget {
  const _ConnectedNavigationBar({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      height: 68,
      elevation: 8,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      indicatorColor: _colorForIndex(selectedIndex).withValues(alpha: 0.14),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: <NavigationDestination>[
        NavigationDestination(
          icon: const Icon(Icons.fitness_center_outlined),
          selectedIcon: const Icon(Icons.fitness_center),
          label: context.tr('Активность', 'Activity'),
        ),
        NavigationDestination(
          icon: const Icon(Icons.restaurant_outlined),
          selectedIcon: const Icon(Icons.restaurant),
          label: context.tr('Питание', 'Nutrition'),
        ),
        NavigationDestination(
          icon: const Icon(Icons.directions_run_outlined),
          selectedIcon: const Icon(Icons.directions_run),
          label: context.tr('Бег', 'Run'),
        ),
        NavigationDestination(
          icon: const Icon(Icons.person_outline),
          selectedIcon: const Icon(Icons.person),
          label: context.tr('Профиль', 'Profile'),
        ),
      ],
    );
  }

  Color _colorForIndex(int index) {
    return switch (index) {
      0 => const Color(0xFF2478E8),
      1 => const Color(0xFF05AFA8),
      2 => const Color(0xFF8C63F6),
      3 => const Color(0xFF17171C),
      _ => const Color(0xFF2478E8),
    };
  }
}

class _AssistantIntroSheet extends StatelessWidget {
  const _AssistantIntroSheet({
    required this.onOpenChat,
    required this.onOpenHistory,
  });

  final VoidCallback onOpenChat;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    const String introAsset = 'assets/images/kaze_assistant_intro.png';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(26)),
            child: Image.asset(
              introAsset,
              height: 238,
              width: double.infinity,
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Kaze',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr(
              'Помогу с рационом, тренировками, дефицитом калорий и вопросами по фитнесу.',
              'I can help with meal plans, workouts, calorie balance, and fitness questions.',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onOpenChat,
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: Text(context.tr('Чат', 'Chat')),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                onPressed: onOpenHistory,
                icon: const Icon(Icons.history),
                tooltip: context.tr('История чатов', 'Chat history'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KazeLogoMark extends StatelessWidget {
  const _KazeLogoMark();

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.asset('assets/images/kaze_logo.png', fit: BoxFit.cover),
    );
  }
}

enum _KazeVisualState {
  greeting,
  thinking,
  food,
  workout,
  run,
  sleep,
  reminder,
  goodbye,
}

String _kazeAssetForVisual(
  _KazeVisualState state, {
  AppLanguage language = AppLanguage.ru,
}) {
  if (language == AppLanguage.en) {
    return switch (state) {
      _KazeVisualState.greeting => 'assets/images/kaze_state_greeting_eng.png',
      _KazeVisualState.thinking => 'assets/images/kaze_state_thinking_eng.png',
      _KazeVisualState.food => 'assets/images/kaze_state_nutrition_eng.png',
      _KazeVisualState.workout => 'assets/images/kaze_state_workout_eng.png',
      _KazeVisualState.run => 'assets/images/kaze_state_running_eng.png',
      _KazeVisualState.sleep => 'assets/images/kaze_state_sleep_eng.png',
      _KazeVisualState.reminder => 'assets/images/kaze_state_reminder_eng.png',
      _KazeVisualState.goodbye => 'assets/images/kaze_state_goodbye_eng.png',
    };
  }
  return switch (state) {
    _KazeVisualState.greeting => 'assets/images/kaze_assistant_chat.png',
    _KazeVisualState.thinking => 'assets/images/kaze_state_thinking.png',
    _KazeVisualState.food => 'assets/images/kaze_state_food.png',
    _KazeVisualState.workout => 'assets/images/kaze_state_workout.png',
    _KazeVisualState.run => 'assets/images/kaze_state_run.png',
    _KazeVisualState.sleep => 'assets/images/kaze_state_sleep.png',
    _KazeVisualState.reminder => 'assets/images/kaze_state_reminder.png',
    _KazeVisualState.goodbye => 'assets/images/kaze_state_goodbye.png',
  };
}

bool _kazeIsNight(DateTime time) => time.hour >= 23 || time.hour < 6;

_KazeVisualState _kazeVisualForPrompt(String prompt, {DateTime? now}) {
  final String text = prompt.toLowerCase();
  if (_containsKazeKeywords(text, const <String>[
    'пока',
    'до встречи',
    'увидимся',
    'спасибо',
    'благодар',
    'bye',
    'thanks',
  ])) {
    return _KazeVisualState.goodbye;
  }
  if (_containsKazeKeywords(text, const <String>[
    'еда',
    'пит',
    'бжу',
    'калор',
    'рацион',
    'меню',
    'блюд',
    'покуп',
    'protein',
    'food',
    'meal',
  ])) {
    return _KazeVisualState.food;
  }
  if (_containsKazeKeywords(text, const <String>[
    'бег',
    'пробеж',
    'километр',
    'марафон',
    'темп',
    'run',
    'running',
  ])) {
    return _KazeVisualState.run;
  }
  if (_containsKazeKeywords(text, const <String>[
    'трен',
    'упраж',
    'подход',
    'мышц',
    'зал',
    'гантел',
    'workout',
    'exercise',
  ])) {
    return _KazeVisualState.workout;
  }
  if (_kazeIsNight(now ?? DateTime.now())) {
    return _KazeVisualState.sleep;
  }
  return _KazeVisualState.greeting;
}

bool _containsKazeKeywords(String text, List<String> keywords) {
  return keywords.any((String keyword) => text.contains(keyword));
}

const String _kazeAssistantUrl = String.fromEnvironment('KAZE_ASSISTANT_URL');
const String _legacyKazeFunctionUrl = String.fromEnvironment(
  'KAZE_FUNCTION_URL',
);

String get _kazeAssistantEndpoint {
  return _kazeAssistantUrl.isNotEmpty
      ? _kazeAssistantUrl
      : _legacyKazeFunctionUrl;
}

class KazeCloudAssistantService {
  const KazeCloudAssistantService();

  static const Duration _timeout = Duration(seconds: 12);

  Future<String?> reply({required AppData data, required String prompt}) async {
    final User? user = FirebaseAuth.instance.currentUser;
    final String endpoint = _kazeAssistantEndpoint.trim();
    if (user == null || endpoint.isEmpty) {
      return null;
    }
    final String? idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      return null;
    }
    final HttpClient client = HttpClient()..connectionTimeout = _timeout;
    try {
      final HttpClientRequest request = await client
          .postUrl(Uri.parse(endpoint))
          .timeout(_timeout);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $idToken');
      request.write(
        jsonEncode(<String, dynamic>{
          'message': prompt,
          'language': data.settings.language.name,
          'context': _contextFor(data),
        }),
      );
      final HttpClientResponse response = await request.close().timeout(
        _timeout,
      );
      final String body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final Object? decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final Object? reply = decoded['reply'];
      return reply is String && reply.trim().isNotEmpty ? reply.trim() : null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Map<String, dynamic> _contextFor(AppData data) {
    final DateTime from = DateTime.now().subtract(const Duration(days: 7));
    final _NutritionTargets targets = _nutritionTargetsFor(data.profile);
    return <String, dynamic>{
      'profile': data.profile.toJson(),
      'settings': data.settings.toJson(),
      'nutritionTargets': <String, dynamic>{
        'calories': targets.calories,
        'protein': targets.protein,
        'fat': targets.fat,
        'carbs': targets.carbs,
      },
      'last7Days': <String, dynamic>{
        'foodEntries': data.foodEntries
            .where((FoodEntry entry) => entry.date.isAfter(from))
            .take(24)
            .map((FoodEntry entry) => entry.toJson())
            .toList(growable: false),
        'completedWorkouts': data.completedWorkouts
            .where(
              (CompletedWorkout workout) => workout.completedAt.isAfter(from),
            )
            .take(12)
            .map((CompletedWorkout workout) => workout.toJson())
            .toList(growable: false),
        'runs': data.runs
            .where((RunEntry run) => run.startedAt.isAfter(from))
            .take(12)
            .map(
              (RunEntry run) => <String, dynamic>{
                'startedAtIso': run.startedAtIso,
                'durationSeconds': run.durationSeconds,
                'distanceKm': run.distanceKm,
                'routePointCount': run.route.length,
              },
            )
            .toList(growable: false),
      },
      'plannedWorkouts': data.plannedWorkouts
          .take(12)
          .map((PlannedWorkout workout) => workout.toJson())
          .toList(growable: false),
      'totals': <String, dynamic>{
        'completedWorkouts': data.completedWorkouts.length,
        'foodEntries': data.foodEntries.length,
        'runs': data.runs.length,
        'totalRunKm': data.runs.fold<double>(
          0,
          (double sum, RunEntry run) => sum + run.distanceKm,
        ),
      },
    };
  }
}

class _AssistantStateImage extends StatelessWidget {
  const _AssistantStateImage({required this.assetPath, required this.thinking});

  final String assetPath;
  final bool thinking;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.all(Radius.circular(24)),
          border: Border.all(color: const Color(0xFFE6EEF6)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(24)),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: Stack(
              key: ValueKey<String>(assetPath),
              children: [
                Image.asset(
                  assetPath,
                  height: 188,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  errorBuilder:
                      (
                        BuildContext context,
                        Object error,
                        StackTrace? stackTrace,
                      ) {
                        return Image.asset(
                          _kazeAssetForVisual(_KazeVisualState.greeting),
                          height: 188,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                        );
                      },
                ),
                if (thinking)
                  const Positioned(
                    right: 14,
                    top: 14,
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _AssistantAvatarArt extends StatelessWidget {
  const _AssistantAvatarArt({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _AssistantAvatarPainter(compact: compact),
      child: const SizedBox.expand(),
    );
  }
}

class _AssistantAvatarPainter extends CustomPainter {
  const _AssistantAvatarPainter({required this.compact});

  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..isAntiAlias = true;
    final double w = size.width;
    final double h = size.height;
    final Color line = const Color(0xFF716995);
    final Color soft = const Color(0xFFEFEAFB);
    final Color skin = const Color(0xFFF5D4C9);
    final Color navy = const Color(0xFF232A52);

    paint.color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(compact ? w / 2 : 34),
      ),
      paint,
    );

    paint.color = soft;
    canvas.drawCircle(Offset(w * 0.62, h * 0.52), min(w, h) * 0.34, paint);
    if (!compact) {
      paint.color = const Color(0xFFE7F4E8);
      canvas.drawCircle(Offset(w * 0.15, h * 0.54), 24, paint);
      paint.color = const Color(0xFFECE8FA);
      canvas.drawCircle(Offset(w * 0.15, h * 0.28), 24, paint);
      paint.color = const Color(0xFFE9EFFB);
      canvas.drawCircle(Offset(w * 0.15, h * 0.79), 24, paint);
    }

    paint.color = skin;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.57, h * 0.49),
        width: w * 0.28,
        height: h * 0.36,
      ),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.70, h * 0.50),
        width: w * 0.08,
        height: h * 0.11,
      ),
      paint,
    );

    paint.color = navy;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.48, h * 0.68, w * 0.34, h * 0.28),
        const Radius.circular(18),
      ),
      paint,
    );
    paint.color = const Color(0xFFF7F5FF);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.38, h * 0.72, w * 0.42, h * 0.26),
        const Radius.circular(22),
      ),
      paint,
    );

    final ui.Path hair = ui.Path()
      ..moveTo(w * 0.42, h * 0.38)
      ..quadraticBezierTo(w * 0.40, h * 0.16, w * 0.58, h * 0.22)
      ..quadraticBezierTo(w * 0.62, h * 0.04, w * 0.70, h * 0.24)
      ..quadraticBezierTo(w * 0.84, h * 0.20, w * 0.74, h * 0.38)
      ..quadraticBezierTo(w * 0.82, h * 0.45, w * 0.68, h * 0.45)
      ..quadraticBezierTo(w * 0.56, h * 0.35, w * 0.42, h * 0.38)
      ..close();
    paint.color = const Color(0xFFF9F8FF);
    canvas.drawPath(hair, paint);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = compact ? 1.1 : 2
      ..color = line;
    canvas.drawPath(hair, paint);
    paint.style = PaintingStyle.fill;

    paint.color = const Color(0xFF6E8ED8);
    canvas.drawCircle(Offset(w * 0.53, h * 0.48), compact ? 3.5 : 8, paint);
    canvas.drawCircle(Offset(w * 0.65, h * 0.46), compact ? 3.5 : 8, paint);
    paint.color = Colors.white;
    canvas.drawCircle(Offset(w * 0.51, h * 0.46), compact ? 1.2 : 3, paint);
    canvas.drawCircle(Offset(w * 0.63, h * 0.44), compact ? 1.2 : 3, paint);

    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = compact ? 1.2 : 2
      ..strokeCap = StrokeCap.round
      ..color = line;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w * 0.59, h * 0.56),
        width: w * 0.09,
        height: h * 0.05,
      ),
      0.2,
      1.2,
      false,
      paint,
    );
    canvas.drawLine(
      Offset(w * 0.72, h * 0.82),
      Offset(w * 0.75, h * 0.89),
      paint,
    );
    canvas.drawLine(
      Offset(w * 0.75, h * 0.89),
      Offset(w * 0.71, h * 0.89),
      paint,
    );
    paint.style = PaintingStyle.fill;

    if (!compact) {
      _drawMiniIcon(
        canvas,
        Offset(w * 0.15, h * 0.28),
        Icons.fitness_center,
        line,
      );
      _drawMiniIcon(
        canvas,
        Offset(w * 0.15, h * 0.54),
        Icons.restaurant,
        const Color(0xFF579E6B),
      );
      _drawMiniIcon(
        canvas,
        Offset(w * 0.15, h * 0.79),
        Icons.directions_run,
        const Color(0xFF5871B6),
      );
    }
  }

  void _drawMiniIcon(Canvas canvas, Offset center, IconData icon, Color color) {
    final TextPainter painter = TextPainter(textDirection: TextDirection.ltr);
    painter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: color,
        fontSize: 25,
      ),
    );
    painter.layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _AssistantAvatarPainter oldDelegate) {
    return oldDelegate.compact != compact;
  }
}

class AssistantChatScreen extends StatefulWidget {
  const AssistantChatScreen({
    super.key,
    required this.appData,
    required this.onChanged,
    this.showHistoryInitially = false,
  });

  final AppData appData;
  final Future<void> Function(List<AssistantConversation> conversations)
  onChanged;
  final bool showHistoryInitially;

  @override
  State<AssistantChatScreen> createState() => _AssistantChatScreenState();
}

class _AssistantChatScreenState extends State<AssistantChatScreen> {
  final TextEditingController _messageCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  late List<AssistantConversation> _conversations;
  late String _activeId;
  bool _showHistory = false;
  bool _thinking = false;
  late String _visualAsset;

  AssistantConversation get _activeConversation {
    return _conversations.firstWhere(
      (AssistantConversation e) => e.id == _activeId,
    );
  }

  @override
  void initState() {
    super.initState();
    final AppLanguage language =
        _activeAppLanguage ?? widget.appData.settings.language;
    _showHistory = widget.showHistoryInitially;
    _conversations = List<AssistantConversation>.from(
      widget.appData.assistantConversations,
    );
    if (_conversations.isEmpty) {
      _conversations.add(_createConversation(language));
    } else {
      _conversations = _conversations
          .map(
            (AssistantConversation conversation) =>
                _localizedDefaultConversation(conversation, language),
          )
          .toList();
    }
    _activeId = _conversations.first.id;
    _visualAsset = _kazeIsNight(DateTime.now())
        ? _kazeAssetForVisual(_KazeVisualState.sleep, language: language)
        : _kazeAssetForVisual(_KazeVisualState.greeting, language: language);
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  String _defaultChatTitle(AppLanguage language) {
    return language == AppLanguage.en ? 'New chat' : 'Новый чат';
  }

  String _assistantGreeting(AppLanguage language) {
    return language == AppLanguage.en
        ? 'Hi! I can see your profile, goal, calorie target, and the last 7 days of nutrition/workouts. Ask me about meals, training, calorie balance, or supplements.'
        : 'Привет! Я вижу твой профиль, цель, норму калорий и последние 7 дней питания/тренировок. Спроси про рацион, тренировку, дефицит или добавки.';
  }

  bool _isDefaultChatTitle(String title) {
    return title == _defaultChatTitle(AppLanguage.ru) ||
        title == _defaultChatTitle(AppLanguage.en);
  }

  bool _isDefaultAssistantGreeting(String text) {
    return text == _assistantGreeting(AppLanguage.ru) ||
        text == _assistantGreeting(AppLanguage.en);
  }

  AssistantConversation _localizedDefaultConversation(
    AssistantConversation conversation,
    AppLanguage language,
  ) {
    final List<AssistantMessage> messages = <AssistantMessage>[
      ...conversation.messages,
    ];
    if (messages.isNotEmpty &&
        messages.first.role == 'assistant' &&
        _isDefaultAssistantGreeting(messages.first.text)) {
      messages[0] = AssistantMessage(
        role: 'assistant',
        text: _assistantGreeting(language),
        createdAtIso: messages.first.createdAtIso,
      );
    }
    return conversation.copyWith(
      title: _isDefaultChatTitle(conversation.title)
          ? _defaultChatTitle(language)
          : conversation.title,
      messages: messages,
    );
  }

  AssistantConversation _createConversation(AppLanguage language) {
    final String now = DateTime.now().toIso8601String();
    return AssistantConversation(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: _defaultChatTitle(language),
      createdAtIso: now,
      updatedAtIso: now,
      messages: <AssistantMessage>[
        AssistantMessage(
          role: 'assistant',
          text: _assistantGreeting(language),
          createdAtIso: now,
        ),
      ],
    );
  }

  Future<void> _save() async {
    await widget.onChanged(_conversations);
  }

  void _startNewChat() {
    setState(() {
      final AssistantConversation conversation = _createConversation(
        context.lang,
      );
      _conversations.insert(0, conversation);
      _activeId = conversation.id;
      _showHistory = false;
    });
    _save();
  }

  void _selectConversation(String id) {
    setState(() {
      _activeId = id;
      _showHistory = false;
    });
  }

  Future<void> _sendMessage([String? quickText]) async {
    if (_thinking) {
      return;
    }
    final String text = (quickText ?? _messageCtrl.text).trim();
    if (text.isEmpty) {
      return;
    }
    final AppLanguage language = context.lang;
    final AppData localizedData = widget.appData.copyWith(
      settings: widget.appData.settings.copyWith(language: language),
    );
    _messageCtrl.clear();
    final String now = DateTime.now().toIso8601String();
    final AssistantMessage userMessage = AssistantMessage(
      role: 'user',
      text: text,
      createdAtIso: now,
    );
    setState(() {
      final int index = _conversations.indexWhere(
        (AssistantConversation e) => e.id == _activeId,
      );
      final AssistantConversation current = _conversations[index];
      final bool defaultTitle = _isDefaultChatTitle(current.title);
      final String title = defaultTitle
          ? (text.length > 34 ? '${text.substring(0, 34)}...' : text)
          : current.title;
      final AssistantConversation updated = current.copyWith(
        title: title,
        updatedAtIso: DateTime.now().toIso8601String(),
        messages: <AssistantMessage>[...current.messages, userMessage],
      );
      _conversations
        ..removeAt(index)
        ..insert(0, updated);
      _activeId = updated.id;
      _thinking = true;
      _visualAsset = _kazeAssetForVisual(
        _KazeVisualState.thinking,
        language: language,
      );
    });
    await _scrollToEnd(delay: const Duration(milliseconds: 60));
    await Future<void>.delayed(const Duration(milliseconds: 520));
    if (!mounted) return;
    final AssistantMessage assistantMessage = AssistantMessage(
      role: 'assistant',
      text: await _replyToMessage(text, localizedData),
      createdAtIso: DateTime.now().toIso8601String(),
    );
    setState(() {
      final int index = _conversations.indexWhere(
        (AssistantConversation e) => e.id == _activeId,
      );
      final AssistantConversation current = _conversations[index];
      final AssistantConversation updated = current.copyWith(
        updatedAtIso: DateTime.now().toIso8601String(),
        messages: <AssistantMessage>[...current.messages, assistantMessage],
      );
      _conversations
        ..removeAt(index)
        ..insert(0, updated);
      _activeId = updated.id;
      _thinking = false;
      _visualAsset = _kazeAssetForVisual(
        _kazeVisualForPrompt(text),
        language: language,
      );
    });
    await _save();
    await _scrollToEnd(delay: const Duration(milliseconds: 80));
  }

  Future<String> _replyToMessage(String text, AppData data) async {
    final String? cloudReply = await KazeCloudAssistantService().reply(
      data: data,
      prompt: text,
    );
    return cloudReply ?? _AssistantEngine(data).reply(text);
  }

  Future<void> _scrollToEnd({required Duration delay}) async {
    await Future<void>.delayed(delay);
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AssistantConversation conversation = _activeConversation;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kaze'),
        actions: [
          IconButton(
            onPressed: _startNewChat,
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: context.tr('Новый чат', 'New chat'),
          ),
          IconButton(
            onPressed: () => setState(() => _showHistory = !_showHistory),
            icon: const Icon(Icons.history),
            tooltip: context.tr('История', 'History'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showHistory)
            _AssistantHistoryPanel(
              conversations: _conversations,
              activeId: _activeId,
              onSelect: _selectConversation,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: _AssistantStateImage(
              assetPath: _visualAsset,
              thinking: _thinking,
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              itemCount: conversation.messages.length,
              itemBuilder: (BuildContext context, int index) {
                final AssistantMessage message = conversation.messages[index];
                return _AssistantMessageBubble(message: message);
              },
            ),
          ),
          _AssistantQuickPrompts(
            onPrompt: (String prompt) => _sendMessage(prompt),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageCtrl,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: context.tr(
                          'Спроси про питание, тренировку или БЖУ',
                          'Ask about nutrition, workouts, or macros',
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _thinking ? null : () => _sendMessage(),
                    icon: const Icon(Icons.send),
                    tooltip: context.tr('Отправить', 'Send'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantHistoryPanel extends StatelessWidget {
  const _AssistantHistoryPanel({
    required this.conversations,
    required this.activeId,
    required this.onSelect,
  });

  final List<AssistantConversation> conversations;
  final String activeId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SizedBox(
        height: 172,
        child: ListView.separated(
          padding: const EdgeInsets.all(10),
          itemCount: conversations.length,
          separatorBuilder: (BuildContext context, int index) =>
              const SizedBox(height: 8),
          itemBuilder: (BuildContext context, int index) {
            final AssistantConversation conversation = conversations[index];
            return ListTile(
              selected: conversation.id == activeId,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              leading: const Icon(Icons.chat_bubble_outline),
              title: Text(
                conversation.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${conversation.updatedAt.day.toString().padLeft(2, '0')}.'
                '${conversation.updatedAt.month.toString().padLeft(2, '0')}.'
                '${conversation.updatedAt.year}',
              ),
              onTap: () => onSelect(conversation.id),
            );
          },
        ),
      ),
    );
  }
}

class _AssistantQuickPrompts extends StatelessWidget {
  const _AssistantQuickPrompts({required this.onPrompt});

  final ValueChanged<String> onPrompt;

  @override
  Widget build(BuildContext context) {
    final List<String> prompts = <String>[
      context.tr('Рацион на день', 'Daily meal plan'),
      context.tr('Тренировка при усталости 6/10', 'Workout for fatigue 6/10'),
      context.tr('Рассчитай дефицит', 'Calculate deficit'),
      context.tr('Список покупок', 'Shopping list'),
    ];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: prompts.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          return ActionChip(
            label: Text(prompts[index]),
            onPressed: () => onPrompt(prompts[index]),
          );
        },
      ),
    );
  }
}

class _AssistantMessageBubble extends StatelessWidget {
  const _AssistantMessageBubble({required this.message});

  final AssistantMessage message;

  @override
  Widget build(BuildContext context) {
    final bool user = message.role == 'user';
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: user ? colors.primary : colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            message.text,
            style: TextStyle(color: user ? colors.onPrimary : colors.onSurface),
          ),
        ),
      ),
    );
  }
}

class _NutritionTargets {
  const _NutritionTargets({
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
  });

  final int calories;
  final int protein;
  final int fat;
  final int carbs;
}

_NutritionTargets _nutritionTargetsFor(UserProfile profile) {
  final double bmr =
      10 * profile.weightKg +
      6.25 * profile.heightCm -
      5 * profile.age +
      (profile.gender == Gender.male ? 5 : -161);
  final double activity = 1.2 + min(profile.workoutsPerWeek, 6) * 0.06;
  double calories = bmr * activity;
  if (profile.goal == Goal.weightLoss) calories -= 350;
  if (profile.goal == Goal.gainMass) calories += 300;
  final int kcal = max(1300, calories.round());
  final double proteinFactor = profile.goal == Goal.gainMass ? 2.0 : 1.8;
  final double fatFactor = profile.goal == Goal.weightLoss ? 0.8 : 0.9;
  final int protein = (profile.weightKg * proteinFactor).round();
  final int fat = (profile.weightKg * fatFactor).round();
  final int carbs = max(80, ((kcal - protein * 4 - fat * 9) / 4).round());
  return _NutritionTargets(
    calories: kcal,
    protein: protein,
    fat: fat,
    carbs: carbs,
  );
}

int _dailyBurnTargetFor(UserProfile profile) {
  final int base = switch (profile.goal) {
    Goal.weightLoss => 520,
    Goal.maintain => 390,
    Goal.gainMass => 320,
  };
  final int weightAdjustment = ((profile.weightKg - 70) * 3).round();
  final int trainingAdjustment = profile.workoutsPerWeek * 18;
  return max(240, base + weightAdjustment + trainingAdjustment);
}

double _estimatedWorkoutCalories(
  CompletedWorkout workout,
  UserProfile profile,
) {
  final int exercises = max(1, workout.exercises.length);
  final double avgSets =
      workout.exercises.fold<double>(
        0,
        (double sum, PlannedExercise e) => sum + e.sets,
      ) /
      exercises;
  final double met = (4.8 + exercises * 0.18 + avgSets * 0.22).clamp(5.2, 8.4);
  final double minutes = max(18, workout.durationSeconds / 60);
  return met * 3.5 * profile.weightKg / 200 * minutes;
}

List<Map<String, dynamic>> _achievementSnapshotsFor(AppData data) {
  final int workoutCount = data.completedWorkouts.length;
  final int runCount = data.runs.length;
  final double runKm = data.runs.fold<double>(
    0,
    (double sum, RunEntry run) => sum + run.distanceKm,
  );
  return <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'workout_first',
      'group': 'workouts',
      'title': 'Первые шаги',
      'titleEn': 'First steps',
      'description': 'Сделать 1 физическую тренировку',
      'descriptionEn': 'Complete 1 strength workout',
      'done': workoutCount >= 1,
      'progress': workoutCount,
      'target': 1,
    },
    <String, dynamic>{
      'id': 'workout_10',
      'group': 'workouts',
      'title': 'Разогнался',
      'titleEn': 'Getting momentum',
      'description': 'Сделать 10 физических тренировок',
      'descriptionEn': 'Complete 10 strength workouts',
      'done': workoutCount >= 10,
      'progress': workoutCount,
      'target': 10,
    },
    <String, dynamic>{
      'id': 'workout_100',
      'group': 'workouts',
      'title': 'Машина',
      'titleEn': 'Machine',
      'description': 'Сделать 100 физических тренировок',
      'descriptionEn': 'Complete 100 strength workouts',
      'done': workoutCount >= 100,
      'progress': workoutCount,
      'target': 100,
    },
    <String, dynamic>{
      'id': 'run_first',
      'group': 'runs',
      'title': 'Беговой старт',
      'titleEn': 'Running start',
      'description': 'Завершить 1 пробежку',
      'descriptionEn': 'Finish 1 run',
      'done': runCount >= 1,
      'progress': runCount,
      'target': 1,
    },
    <String, dynamic>{
      'id': 'run_10',
      'group': 'runs',
      'title': 'Ритм',
      'titleEn': 'Rhythm',
      'description': 'Завершить 10 пробежек',
      'descriptionEn': 'Finish 10 runs',
      'done': runCount >= 10,
      'progress': runCount,
      'target': 10,
    },
    <String, dynamic>{
      'id': 'run_50',
      'group': 'runs',
      'title': 'Дистанция',
      'titleEn': 'Distance',
      'description': 'Завершить 50 пробежек',
      'descriptionEn': 'Finish 50 runs',
      'done': runCount >= 50,
      'progress': runCount,
      'target': 50,
    },
    <String, dynamic>{
      'id': 'run_marathon_distance',
      'group': 'runs',
      'title': '42.195',
      'titleEn': '42.195',
      'description': 'Набрать марафонскую дистанцию суммарно',
      'descriptionEn': 'Reach a marathon distance in total',
      'done': runKm >= 42.195,
      'progress': runKm,
      'target': 42.195,
    },
  ];
}

bool _sameCalendarDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

const Map<String, String> _exerciseNamesEn = <String, String>{
  'Приседания': 'Squats',
  'Жим лежа': 'Bench press',
  'Тяга в наклоне': 'Bent-over row',
  'Румынская тяга': 'Romanian deadlift',
  'Планка': 'Plank',
  'Жим гантелей под углом': 'Incline dumbbell press',
  'Разведения гантелей': 'Dumbbell flyes',
  'Подъем штанги на бицепс': 'Barbell curl',
  'Молотковые сгибания': 'Hammer curls',
  'Выпады': 'Lunges',
  'Ягодичный мост': 'Glute bridge',
  'Сгибание ног': 'Leg curl',
  'Подтягивания': 'Pull-ups',
  'Тяга верхнего блока': 'Lat pulldown',
  'Тяга гантели одной рукой': 'One-arm dumbbell row',
  'Французский жим': 'French press',
  'Разгибание рук на блоке': 'Cable triceps extension',
  'Бёрпи': 'Burpees',
  'Прыжки на месте': 'Jumping jacks',
  'Скручивания': 'Crunches',
  'Мобилизация бедер': 'Hip mobility',
  'Растяжка грудного отдела': 'Thoracic stretch',
  'Дыхательная планка': 'Breathing plank',
  'Отжимания': 'Push-ups',
  'Становая тяга': 'Deadlift',
};

String _exerciseNameForLanguage(String name, AppLanguage language) {
  return language == AppLanguage.en ? _exerciseNamesEn[name] ?? name : name;
}

class _WorkoutPreset {
  const _WorkoutPreset({
    required this.title,
    required this.titleEn,
    required this.tag,
    required this.tagEn,
    required this.minutes,
    required this.exercises,
    required this.accent,
    required this.figureIcon,
  });

  final String title;
  final String titleEn;
  final String tag;
  final String tagEn;
  final int minutes;
  final List<PlannedExercise> exercises;
  final Color accent;
  final IconData figureIcon;

  String titleFor(AppLanguage language) {
    return language == AppLanguage.en ? titleEn : title;
  }

  String tagFor(AppLanguage language) {
    return language == AppLanguage.en ? tagEn : tag;
  }
}

List<_WorkoutPreset> _workoutPresetsFor(UserProfile profile) {
  final int baseSets = switch (profile.goal) {
    Goal.weightLoss => 3,
    Goal.maintain => 3,
    Goal.gainMass => 4,
  };
  final int baseReps = switch (profile.goal) {
    Goal.weightLoss => 14,
    Goal.maintain => 11,
    Goal.gainMass => 8,
  };
  final int levelBoost = profile.workoutsPerWeek >= 5 ? 1 : 0;
  PlannedExercise ex(String name, {int setDelta = 0, int repDelta = 0}) {
    return PlannedExercise(
      name: name,
      sets: max(2, baseSets + levelBoost + setDelta),
      reps: max(6, baseReps + repDelta),
    );
  }

  final int minutes = switch (profile.goal) {
    Goal.weightLoss => 38,
    Goal.maintain => 42,
    Goal.gainMass => 50,
  };
  final String tag = switch (profile.goal) {
    Goal.weightLoss => 'жиросжигание',
    Goal.maintain => 'баланс',
    Goal.gainMass => 'масса',
  };
  final String tagEn = switch (profile.goal) {
    Goal.weightLoss => 'fat burn',
    Goal.maintain => 'balance',
    Goal.gainMass => 'muscle gain',
  };
  return <_WorkoutPreset>[
    _WorkoutPreset(
      title: 'Фул боди',
      titleEn: 'Full body workout',
      tag: tag,
      tagEn: tagEn,
      minutes: minutes,
      accent: const Color(0xFF7A8CFF),
      figureIcon: Icons.accessibility_new,
      exercises: <PlannedExercise>[
        ex('Приседания'),
        ex('Жим лежа', repDelta: -1),
        ex('Тяга в наклоне'),
        ex('Румынская тяга', repDelta: -2),
        ex('Планка', setDelta: -1, repDelta: 20),
      ],
    ),
    _WorkoutPreset(
      title: 'Грудь + бицепс',
      titleEn: 'Chest + biceps',
      tag: 'верх тела',
      tagEn: 'upper body',
      minutes: minutes + 4,
      accent: const Color(0xFF9A6CFF),
      figureIcon: Icons.fitness_center,
      exercises: <PlannedExercise>[
        ex('Жим лежа', repDelta: -2),
        ex('Жим гантелей под углом', repDelta: -1),
        ex('Разведения гантелей'),
        ex('Подъем штанги на бицепс', repDelta: -1),
        ex('Молотковые сгибания'),
      ],
    ),
    _WorkoutPreset(
      title: 'Ноги + корпус',
      titleEn: 'Legs + core',
      tag: 'силовая база',
      tagEn: 'strength base',
      minutes: minutes + 2,
      accent: const Color(0xFF55B8FF),
      figureIcon: Icons.sports_martial_arts,
      exercises: <PlannedExercise>[
        ex('Приседания', repDelta: -2),
        ex('Выпады'),
        ex('Ягодичный мост'),
        ex('Сгибание ног'),
        ex('Планка', setDelta: -1, repDelta: 25),
      ],
    ),
    _WorkoutPreset(
      title: 'Спина + трицепс',
      titleEn: 'Back + triceps',
      tag: 'осанка и сила',
      tagEn: 'posture and strength',
      minutes: minutes + 3,
      accent: const Color(0xFF2FC9A6),
      figureIcon: Icons.rowing,
      exercises: <PlannedExercise>[
        ex('Подтягивания', repDelta: -3),
        ex('Тяга верхнего блока', repDelta: -1),
        ex('Тяга гантели одной рукой'),
        ex('Французский жим', repDelta: -1),
        ex('Разгибание рук на блоке'),
      ],
    ),
    _WorkoutPreset(
      title: 'Кардио + пресс',
      titleEn: 'Cardio + abs',
      tag: 'выносливость',
      tagEn: 'endurance',
      minutes: minutes - 4,
      accent: const Color(0xFFFF9D4D),
      figureIcon: Icons.directions_run,
      exercises: <PlannedExercise>[
        ex('Бёрпи', setDelta: -1, repDelta: 4),
        ex('Прыжки на месте', repDelta: 10),
        ex('Скручивания', repDelta: 6),
        ex('Планка', setDelta: -1, repDelta: 25),
      ],
    ),
    _WorkoutPreset(
      title: 'Мобилити recovery',
      titleEn: 'Mobility recovery',
      tag: 'восстановление',
      tagEn: 'recovery',
      minutes: 28,
      accent: const Color(0xFF8C63F6),
      figureIcon: Icons.self_improvement,
      exercises: <PlannedExercise>[
        ex('Мобилизация бедер', setDelta: -1, repDelta: 2),
        ex('Растяжка грудного отдела', setDelta: -1, repDelta: 2),
        ex('Ягодичный мост', setDelta: -1, repDelta: 2),
        ex('Дыхательная планка', setDelta: -1, repDelta: 18),
      ],
    ),
  ];
}

class _AssistantEngine {
  const _AssistantEngine(this.data);

  final AppData data;

  bool get _english => data.settings.language == AppLanguage.en;

  String _tr(String ru, String en) => _english ? en : ru;

  String reply(String prompt) {
    final String text = prompt.toLowerCase();
    if (_containsAny(text, <String>['покуп', 'shopping'])) {
      return _shoppingList();
    }
    if (_containsAny(text, <String>[
      'рацион',
      'меню',
      'план питания',
      'meal',
      'menu',
      'diet',
    ])) {
      return _mealPlan();
    }
    if (_containsAny(text, <String>[
      'альтернатив',
      'замен',
      'alternative',
      'substitute',
      'swap',
    ])) {
      return _healthyAlternative(prompt);
    }
    if (_containsAny(text, <String>[
      'устал',
      'тренировк',
      'нагрузк',
      'fatigue',
      'workout',
      'training',
      'load',
    ])) {
      return _workoutByFatigue(text);
    }
    if (_containsAny(text, <String>[
      'техника',
      'выполнять',
      'упражнен',
      'technique',
      'exercise',
      'form',
    ])) {
      return _exerciseTechnique(prompt);
    }
    if (_containsAny(text, <String>[
      'травм',
      'боль',
      'огранич',
      'injury',
      'pain',
      'limit',
    ])) {
      return _injuryAdaptation();
    }
    if (_containsAny(text, <String>[
      'дефицит',
      'профицит',
      'калори',
      'deficit',
      'surplus',
      'calorie',
    ])) {
      return _calorieBalance();
    }
    if (_containsAny(text, <String>[
      'креатин',
      'протеин',
      'добавк',
      'омега',
      'creatine',
      'protein',
      'supplement',
      'omega',
    ])) {
      return _supplements();
    }
    return _tr(
      '${_contextSummary()}\n\nМогу составить рацион, список покупок, тренировку по усталости, объяснить технику упражнения или посчитать дефицит/профицит калорий.',
      '${_contextSummary()}\n\nI can build a meal plan, create a shopping list, suggest a workout based on fatigue, explain exercise technique, or calculate a calorie deficit/surplus.',
    );
  }

  bool _containsAny(String text, List<String> needles) {
    return needles.any(text.contains);
  }

  _NutritionTargets _targets() {
    return _nutritionTargetsFor(data.profile);
  }

  List<FoodEntry> _lastSevenFoods() {
    final DateTime from = DateTime.now().subtract(const Duration(days: 7));
    return data.foodEntries
        .where((FoodEntry e) => e.date.isAfter(from))
        .toList();
  }

  List<CompletedWorkout> _lastSevenWorkouts() {
    final DateTime from = DateTime.now().subtract(const Duration(days: 7));
    return data.completedWorkouts
        .where((CompletedWorkout e) => e.completedAt.isAfter(from))
        .toList();
  }

  List<RunEntry> _lastSevenRuns() {
    final DateTime from = DateTime.now().subtract(const Duration(days: 7));
    return data.runs.where((RunEntry e) => e.startedAt.isAfter(from)).toList();
  }

  String _contextSummary() {
    final _NutritionTargets t = _targets();
    final List<FoodEntry> foods = _lastSevenFoods();
    final double eaten = foods.fold(
      0,
      (double s, FoodEntry e) => s + e.calories,
    );
    return _tr(
      'Контекст: ${data.profile.weightKg.toStringAsFixed(1)} кг, '
          '${data.profile.heightCm.toStringAsFixed(0)} см, ${data.profile.age} лет, '
          'цель: ${data.profile.goal.label}. Норма: ${t.calories} ккал, '
          'Б/Ж/У ${t.protein}/${t.fat}/${t.carbs} г. '
          'За 7 дней: ${foods.length} записей еды, примерно ${eaten.toStringAsFixed(0)} ккал, '
          '${_lastSevenWorkouts().length} силовых тренировок, ${_lastSevenRuns().length} пробежек.',
      'Context: ${data.profile.weightKg.toStringAsFixed(1)} kg, '
          '${data.profile.heightCm.toStringAsFixed(0)} cm, ${data.profile.age} years old, '
          'goal: ${data.profile.goal.labelFor(AppLanguage.en)}. Target: ${t.calories} kcal, '
          'P/F/C ${t.protein}/${t.fat}/${t.carbs} g. '
          'Last 7 days: ${foods.length} food logs, about ${eaten.toStringAsFixed(0)} kcal, '
          '${_lastSevenWorkouts().length} strength workouts, ${_lastSevenRuns().length} runs.',
    );
  }

  String _mealPlan() {
    final _NutritionTargets t = _targets();
    return _tr(
      '${_contextSummary()}\n\nРацион на день:\n'
          'Завтрак: овсянка на молоке, банан, греческий йогурт.\n'
          'Обед: курица или тофу, гречка, большой салат с оливковым маслом.\n'
          'Перекус: творог/протеиновый йогурт и ягоды.\n'
          'Ужин: рыба или яйца, картофель/рис, овощи.\n\n'
          'Цель дня: около ${t.calories} ккал, БЖУ ${t.protein}/${t.fat}/${t.carbs} г. '
          'Если к вечеру не добираешь белок, добавь 25-30 г протеина или 150-200 г творога.',
      '${_contextSummary()}\n\nMeal plan for the day:\n'
          'Breakfast: oatmeal with milk, banana, Greek yogurt.\n'
          'Lunch: chicken or tofu, buckwheat, a large salad with olive oil.\n'
          'Snack: cottage cheese/protein yogurt and berries.\n'
          'Dinner: fish or eggs, potatoes/rice, vegetables.\n\n'
          'Daily target: about ${t.calories} kcal, P/F/C ${t.protein}/${t.fat}/${t.carbs} g. '
          'If protein is low by evening, add 25-30 g of protein powder or 150-200 g of cottage cheese.',
    );
  }

  String _healthyAlternative(String prompt) {
    return _tr(
      'Здоровая замена: оставь вкус блюда, но снизь плотность калорий. '
          'Жарку замени запеканием, майонезный соус - йогуртом с горчицей, '
          'часть быстрых углеводов - овощами или крупой. Если речь про "$prompt", '
          'напиши конкретное блюдо и порцию, я пересоберу вариант под твою норму БЖУ.',
      'Healthy swap: keep the flavor, lower calorie density. '
          'Replace frying with baking, mayo sauce with yogurt and mustard, '
          'and part of fast carbs with vegetables or grains. If you mean "$prompt", '
          'send the exact dish and portion and I will rebuild it around your macros.',
    );
  }

  String _shoppingList() {
    return _tr(
      'Список покупок на неделю:\n'
          'Белок: куриная грудка/бедро без кожи, яйца, творог, греческий йогурт, рыба, фасоль или тофу.\n'
          'Углеводы: овсянка, гречка, рис, картофель, цельнозерновой хлеб.\n'
          'Жиры: оливковое масло, орехи, авокадо.\n'
          'Овощи и фрукты: салатная смесь, огурцы, томаты, брокколи, ягоды, бананы, яблоки.\n'
          'Быстрое: протеин по желанию, замороженные овощи, консервированный тунец.',
      'Weekly shopping list:\n'
          'Protein: chicken breast/skinless thigh, eggs, cottage cheese, Greek yogurt, fish, beans or tofu.\n'
          'Carbs: oats, buckwheat, rice, potatoes, whole-grain bread.\n'
          'Fats: olive oil, nuts, avocado.\n'
          'Vegetables and fruit: salad mix, cucumbers, tomatoes, broccoli, berries, bananas, apples.\n'
          'Quick options: protein powder if needed, frozen vegetables, canned tuna.',
    );
  }

  String _workoutByFatigue(String text) {
    final RegExpMatch? match = RegExp(r'([1-9]|10)').firstMatch(text);
    final int fatigue = match == null ? 5 : int.parse(match.group(0)!);
    if (fatigue >= 8) {
      return _tr(
        'Усталость $fatigue/10: сегодня лучше восстановительная сессия 20-30 минут. '
            'Легкая ходьба, мобилити, растяжка грудного отдела/бедер, 2-3 простых упражнения без отказа. '
            'Силовую нагрузку перенеси, сон и вода важнее.',
        'Fatigue $fatigue/10: today is better for a 20-30 minute recovery session. '
            'Easy walking, mobility, chest/hip stretching, and 2-3 simple exercises far from failure. '
            'Move heavy lifting to another day; sleep and hydration matter more.',
      );
    }
    if (fatigue >= 5) {
      return _tr(
        'Усталость $fatigue/10: сделай умеренную тренировку. '
            'Разминка 8 минут, затем 3 круга: присед 10-12, тяга/наклон 10, отжимания 8-12, планка 30-40 сек. '
            'Остановись за 2-3 повтора до отказа.',
        'Fatigue $fatigue/10: do a moderate workout. '
            'Warm up for 8 minutes, then 3 rounds: squat 10-12, row/hinge 10, push-ups 8-12, plank 30-40 sec. '
            'Stop 2-3 reps before failure.',
      );
    }
    return _tr(
      'Усталость $fatigue/10: можно полноценную тренировку. '
          'Разминка, 4 базовых упражнения по 3-4 подхода, затем короткая заминка. '
          'Следи за техникой и не повышай вес, если скорость повторов резко падает.',
      'Fatigue $fatigue/10: a full workout is fine. '
          'Warm up, do 4 basic exercises for 3-4 sets, then a short cooldown. '
          'Watch technique and do not increase weight if rep speed drops sharply.',
    );
  }

  String _exerciseTechnique(String prompt) {
    return _tr(
      'Техника упражнения: начни с устойчивой позиции, держи корпус собранным, '
          'движение выполняй контролируемо, без рывков, боль в суставе - стоп-сигнал. '
          'Для приседа: колени идут по линии носков, спина нейтральная, вес на середине стопы. '
          'Для жима/отжиманий: лопатки стабильны, локти не разваливаются строго в стороны. '
          'Напиши конкретное упражнение из "$prompt", и я разберу его по шагам.',
      'Exercise technique: start from a stable position, keep your torso braced, '
          'move with control and no jerking; joint pain is a stop signal. '
          'For squats: knees track with toes, spine neutral, weight mid-foot. '
          'For presses/push-ups: stable shoulder blades, elbows not flared straight out. '
          'Send the exact exercise from "$prompt" and I will break it down step by step.',
    );
  }

  String _injuryAdaptation() {
    return _tr(
      'Адаптация под ограничение: убери движения, которые вызывают боль, снизь амплитуду и интенсивность, '
          'замени ударную нагрузку на велотренажер/ходьбу, а силовые делай в диапазоне без боли. '
          'При острой боли, онемении или ухудшении лучше обратиться к врачу/реабилитологу. '
          'Напиши место травмы и какие упражнения провоцируют боль, подберу замены.',
      'Adapting around a limitation: remove movements that cause pain, reduce range and intensity, '
          'replace impact with cycling/walking, and keep strength work in a pain-free range. '
          'For sharp pain, numbness, or worsening symptoms, talk to a doctor/rehab specialist. '
          'Tell me where the injury is and which exercises trigger pain; I will suggest swaps.',
    );
  }

  String _calorieBalance() {
    final _NutritionTargets t = _targets();
    return _tr(
      '${_contextSummary()}\n\nОриентир: поддержание около ${t.calories} ккал с учетом цели в профиле. '
          'Для похудения держи дефицит 300-500 ккал от поддержания и белок ${t.protein} г. '
          'Для набора держи профицит 200-350 ккал и отслеживай вес 2-3 недели. '
          'Если вес меняется быстрее 0.5-1% массы в неделю, скорректируй рацион на 100-200 ккал.',
      '${_contextSummary()}\n\nReference point: maintenance is about ${t.calories} kcal based on your profile goal. '
          'For weight loss, keep a 300-500 kcal deficit from maintenance and protein around ${t.protein} g. '
          'For gaining, keep a 200-350 kcal surplus and track weight for 2-3 weeks. '
          'If weight changes faster than 0.5-1% body weight per week, adjust by 100-200 kcal.',
    );
  }

  String _supplements() {
    return _tr(
      'Добавки: креатин моногидрат 3-5 г ежедневно обычно уместен для силы и мощности. '
          'Протеин - просто удобный способ добрать белок, если едой не выходит. '
          'Омега-3 и витамин D имеют смысл при дефиците в рационе/анализах. '
          'Не смешивай добавки с лечением без консультации врача, особенно при заболеваниях почек, печени или ЖКТ.',
      'Supplements: creatine monohydrate 3-5 g daily is usually useful for strength and power. '
          'Protein powder is just a convenient way to hit protein when food is not enough. '
          'Omega-3 and vitamin D make sense when diet/labs show a gap. '
          'Do not combine supplements with treatment without medical advice, especially with kidney, liver, or GI issues.',
    );
  }
}

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({
    super.key,
    required this.profile,
    required this.plannedWorkouts,
    required this.rememberedExerciseSets,
    required this.completedWorkouts,
    required this.totalWorkouts,
    required this.onScheduleWorkout,
    required this.onUpdatePlannedWorkout,
    required this.onDeletePlannedWorkout,
    required this.onSaveRememberedSets,
    required this.onCompleteWorkout,
  });

  final UserProfile profile;
  final List<PlannedWorkout> plannedWorkouts;
  final Map<String, int> rememberedExerciseSets;
  final List<CompletedWorkout> completedWorkouts;
  final int totalWorkouts;
  final Future<void> Function(
    List<String> names,
    DateTime date, {
    String? editingId,
    List<PlannedExercise>? exercises,
  })
  onScheduleWorkout;
  final Future<void> Function(PlannedWorkout planned) onUpdatePlannedWorkout;
  final Future<void> Function(String id) onDeletePlannedWorkout;
  final Future<void> Function(Map<String, int> values) onSaveRememberedSets;
  final Future<void> Function(
    PlannedWorkout planned,
    WorkoutEmotion emotion,
    int durationSeconds,
  )
  onCompleteWorkout;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  bool _expanded = true;
  Timer? _workoutTimer;
  String? _timerWorkoutId;
  int _workoutSeconds = 0;
  bool _workoutTimerRunning = false;
  final Set<String> _rememberedExercises = <String>{};
  final Map<String, int> _rememberedSets = <String, int>{};

  @override
  void initState() {
    super.initState();
    _rememberedSets.addAll(widget.rememberedExerciseSets);
  }

  @override
  void didUpdateWidget(covariant ActivityScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_timerWorkoutId != null &&
        !widget.plannedWorkouts.any(
          (PlannedWorkout workout) => workout.id == _timerWorkoutId,
        )) {
      _clearWorkoutTimer();
    }
  }

  @override
  void dispose() {
    _workoutTimer?.cancel();
    super.dispose();
  }

  DateTime _normalized(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  PlannedWorkout? _plannedForDate(DateTime date) {
    final DateTime target = _normalized(date);
    for (final PlannedWorkout workout in widget.plannedWorkouts) {
      if (_sameDay(workout.plannedDate, target)) {
        return workout;
      }
    }
    return null;
  }

  double _todayBurnedCalories() {
    final DateTime today = DateTime.now();
    return widget.completedWorkouts
        .where((CompletedWorkout w) => _sameCalendarDay(w.completedAt, today))
        .fold<double>(
          0,
          (double sum, CompletedWorkout w) =>
              sum + _estimatedWorkoutCalories(w, widget.profile),
        );
  }

  Future<void> _schedulePreset(_WorkoutPreset preset) async {
    final DateTime today = _normalized(DateTime.now());
    final DateTime? date = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      initialDate: today,
      locale: Locale(context.lang.name),
    );
    if (date == null) return;
    final DateTime targetDate = _normalized(date);
    final PlannedWorkout? existing = _plannedForDate(targetDate);
    if (existing != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'На выбранную дату уже есть тренировка',
              'A workout is already planned for this date',
            ),
          ),
        ),
      );
      return;
    }
    await widget.onScheduleWorkout(
      preset.exercises.map((PlannedExercise e) => e.name).toList(),
      targetDate,
      exercises: preset.exercises,
    );
  }

  String _fmtDate(DateTime dt) {
    final String dd = dt.day.toString().padLeft(2, '0');
    final String mm = dt.month.toString().padLeft(2, '0');
    final String hh = dt.hour.toString().padLeft(2, '0');
    final String min = dt.minute.toString().padLeft(2, '0');
    return '$dd.$mm.${dt.year} $hh:$min';
  }

  String _fmtDuration(int total) {
    final int h = total ~/ 3600;
    final int m = (total % 3600) ~/ 60;
    final int s = total % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _startWorkoutTimer(PlannedWorkout workout) {
    if (_timerWorkoutId != workout.id) {
      _workoutTimer?.cancel();
      _timerWorkoutId = workout.id;
      _workoutSeconds = 0;
    }
    _workoutTimer?.cancel();
    _workoutTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _workoutSeconds += 1);
    });
    setState(() => _workoutTimerRunning = true);
  }

  void _pauseWorkoutTimer() {
    _workoutTimer?.cancel();
    setState(() => _workoutTimerRunning = false);
  }

  void _resetWorkoutTimer(PlannedWorkout workout) {
    _workoutTimer?.cancel();
    setState(() {
      _timerWorkoutId = workout.id;
      _workoutSeconds = 0;
      _workoutTimerRunning = false;
    });
  }

  void _clearWorkoutTimer() {
    _workoutTimer?.cancel();
    _timerWorkoutId = null;
    _workoutSeconds = 0;
    _workoutTimerRunning = false;
  }

  int _durationForWorkout(PlannedWorkout workout) {
    if (_timerWorkoutId == workout.id) {
      return _workoutSeconds;
    }
    return max(60, DateTime.now().difference(workout.createdAt).inSeconds);
  }

  Widget _buildWorkoutTimer(PlannedWorkout workout) {
    final bool timerAttached = _timerWorkoutId == workout.id;
    final int seconds = timerAttached ? _workoutSeconds : 0;
    final bool running = timerAttached && _workoutTimerRunning;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF2478E8).withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined, color: Color(0xFF2478E8)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr('Таймер тренировки', 'Workout timer'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF102A43),
                  ),
                ),
              ),
              Text(
                _fmtDuration(seconds),
                style: const TextStyle(
                  fontFeatures: <ui.FontFeature>[
                    ui.FontFeature.tabularFigures(),
                  ],
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: Color(0xFF102A43),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: running
                    ? _pauseWorkoutTimer
                    : () => _startWorkoutTimer(workout),
                icon: Icon(running ? Icons.pause : Icons.play_arrow),
                label: Text(
                  running
                      ? context.tr('Пауза', 'Pause')
                      : seconds > 0
                      ? context.tr('Продолжить', 'Resume')
                      : context.tr('Старт', 'Start'),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _resetWorkoutTimer(workout),
                icon: const Icon(Icons.restart_alt),
                label: Text(context.tr('Сбросить', 'Reset')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openPlanDialog({PlannedWorkout? editing}) async {
    const List<String> preset = <String>[
      'Приседания',
      'Жим лежа',
      'Отжимания',
      'Подтягивания',
      'Планка',
      'Становая тяга',
      'Бёрпи',
    ];
    final Set<String> selected = editing != null
        ? editing.exercises.map((PlannedExercise e) => e.name).toSet()
        : <String>{..._rememberedExercises};
    DateTime selectedDate = editing?.plannedDate ?? _normalized(DateTime.now());
    final TextEditingController customCtrl = TextEditingController();
    final _PlanDialogResult? result = await showDialog<_PlanDialogResult>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setState) {
            return AlertDialog(
              title: Text(context.tr('План тренировки', 'Workout plan')),
              content: SizedBox(
                width: 380,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          context.tr('Дата тренировки', 'Workout date'),
                        ),
                        subtitle: Text(
                          '${selectedDate.day.toString().padLeft(2, '0')}.${selectedDate.month.toString().padLeft(2, '0')}.${selectedDate.year}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_calendar),
                          onPressed: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 365),
                              ),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                              initialDate: selectedDate,
                              locale: Locale(context.lang.name),
                            );
                            if (picked != null) {
                              setState(
                                () => selectedDate = _normalized(picked),
                              );
                            }
                          },
                        ),
                      ),
                      for (final String item in preset)
                        CheckboxListTile(
                          value: selected.contains(item),
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            _exerciseNameForLanguage(item, context.lang),
                          ),
                          onChanged: (bool? value) {
                            setState(() {
                              if (value ?? false) {
                                selected.add(item);
                              } else {
                                selected.remove(item);
                              }
                            });
                          },
                        ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: customCtrl,
                        decoration: InputDecoration(
                          labelText: context.tr(
                            'Свое упражнение',
                            'Custom exercise',
                          ),
                          suffixIcon: IconButton(
                            onPressed: () {
                              final String value = customCtrl.text.trim();
                              if (value.isEmpty) {
                                return;
                              }
                              setState(() {
                                selected.add(value);
                                customCtrl.clear();
                              });
                            },
                            icon: const Icon(Icons.add),
                          ),
                        ),
                      ),
                      if (selected.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 6,
                            children: selected
                                .map(
                                  (String e) => Chip(
                                    label: Text(
                                      _exerciseNameForLanguage(e, context.lang),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.tr('Отмена', 'Cancel')),
                ),
                FilledButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () => Navigator.pop(
                          context,
                          _PlanDialogResult(selected.toList(), selectedDate),
                        ),
                  child: Text(context.tr('Добавить', 'Add')),
                ),
              ],
            );
          },
        );
      },
    );
    customCtrl.dispose();
    if (result == null || result.exerciseNames.isEmpty) {
      return;
    }
    final PlannedWorkout? existing = _plannedForDate(result.date);
    if (existing != null && existing.id != editing?.id) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'На эту дату уже есть тренировка',
              'A workout is already planned for this date',
            ),
          ),
        ),
      );
      return;
    }
    setState(() {
      _rememberedExercises
        ..clear()
        ..addAll(result.exerciseNames);
    });
    await widget.onScheduleWorkout(
      result.exerciseNames,
      result.date,
      editingId: editing?.id,
    );
  }

  Future<void> _finishWithEmotion(PlannedWorkout workout) async {
    final WorkoutEmotion? emotion = await showDialog<WorkoutEmotion>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(context.tr('Оцените тренировку', 'Rate the workout')),
          content: Wrap(
            spacing: 10,
            children: WorkoutEmotion.values
                .map(
                  (WorkoutEmotion e) => ChoiceChip(
                    selected: false,
                    label: Text('${e.emoji} ${e.labelFor(context.lang)}'),
                    onSelected: (_) => Navigator.pop(context, e),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
    if (emotion != null) {
      final int durationSeconds = _durationForWorkout(workout);
      await widget.onCompleteWorkout(workout, emotion, durationSeconds);
      if (mounted && _timerWorkoutId == workout.id) {
        setState(_clearWorkoutTimer);
      }
    }
  }

  Future<void> _changeExercise(
    PlannedWorkout workout,
    int index,
    PlannedExercise next,
  ) async {
    final List<PlannedExercise> list = List<PlannedExercise>.from(
      workout.exercises,
    );
    list[index] = next;
    _rememberedSets[next.name] = next.sets;
    await widget.onSaveRememberedSets(Map<String, int>.from(_rememberedSets));
    await widget.onUpdatePlannedWorkout(workout.copyWith(exercises: list));
  }

  Future<void> _openWorkoutCalendar() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 24,
          ),
          child: _WorkoutCalendarSheet(
            plannedWorkouts: widget.plannedWorkouts,
            completedWorkouts: widget.completedWorkouts,
            onDateTap: (DateTime date) async {
              final PlannedWorkout? planned = _plannedForDate(date);
              if (planned == null) {
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(
                        this.context.tr(
                          'На эту дату нет запланированной тренировки',
                          'No workout is planned for this date',
                        ),
                      ),
                    ),
                  );
                }
                return;
              }
              if (!mounted) return;
              await showModalBottomSheet<void>(
                context: this.context,
                builder: (BuildContext context) {
                  return SafeArea(
                    child: Wrap(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.fitness_center_outlined),
                          title: Text(
                            '${this.context.tr('Тренировка', 'Workout')}: ${_fmtDate(planned.plannedDate)}',
                          ),
                          subtitle: Text(
                            planned.exercises
                                .map(
                                  (PlannedExercise exercise) =>
                                      _exerciseNameForLanguage(
                                        exercise.name,
                                        context.lang,
                                      ),
                                )
                                .join(' • '),
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.edit_outlined),
                          title: Text(context.tr('Редактировать', 'Edit')),
                          onTap: () async {
                            Navigator.of(context).pop();
                            await _openPlanDialog(editing: planned);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.event_repeat_outlined),
                          title: Text(
                            context.tr('Перенести дату', 'Move date'),
                          ),
                          onTap: () async {
                            Navigator.of(context).pop();
                            final DateTime? newDate = await showDatePicker(
                              context: this.context,
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 365),
                              ),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                              initialDate: planned.plannedDate,
                              locale: Locale(this.context.lang.name),
                            );
                            if (newDate == null) return;
                            final PlannedWorkout? conflict = _plannedForDate(
                              newDate,
                            );
                            if (conflict != null && conflict.id != planned.id) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    this.context.tr(
                                      'На эту дату уже есть тренировка',
                                      'A workout is already planned for this date',
                                    ),
                                  ),
                                ),
                              );
                              return;
                            }
                            await widget.onUpdatePlannedWorkout(
                              planned.copyWith(
                                plannedDateIso: _normalized(
                                  newDate,
                                ).toIso8601String(),
                              ),
                            );
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.delete_outline),
                          title: Text(
                            context.tr('Удалить тренировку', 'Delete workout'),
                          ),
                          onTap: () async {
                            Navigator.of(context).pop();
                            await widget.onDeletePlannedWorkout(planned.id);
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final PlannedWorkout? active = _plannedForDate(DateTime.now());
    final double burned = _todayBurnedCalories();
    final int burnTarget = _dailyBurnTargetFor(widget.profile);
    final List<_WorkoutPreset> presets = _workoutPresetsFor(widget.profile);
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _openWorkoutCalendar,
        backgroundColor: const Color(0xFF2478E8),
        foregroundColor: Colors.white,
        child: const Icon(Icons.calendar_month_outlined),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _BurnTargetCard(
            burnedCalories: burned,
            targetCalories: burnTarget,
            totalWorkouts: widget.totalWorkouts,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('Готовые тренировки', 'Ready workouts'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF102A43),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _openPlanDialog,
                icon: const Icon(Icons.tune),
                label: Text(context.tr('Своя', 'Custom')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 174,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: presets.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (BuildContext context, int index) {
                final _WorkoutPreset preset = presets[index];
                return _WorkoutPresetCard(
                  preset: preset,
                  onTap: () => _schedulePreset(preset),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          if (active != null)
            Card(
              color: const Color(0xFF2478E8).withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.local_fire_department,
                          color: Color(0xFF2478E8),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.tr('Активная тренировка', 'Active workout'),
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              setState(() => _expanded = !_expanded),
                          icon: Icon(
                            _expanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${context.tr('Начата', 'Started')}: ${_fmtDate(active.createdAt)}',
                    ),
                    const SizedBox(height: 10),
                    _buildWorkoutTimer(active),
                    if (_expanded) ...[
                      const SizedBox(height: 8),
                      for (int i = 0; i < active.exercises.length; i++)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _exerciseNameForLanguage(
                                    active.exercises[i].name,
                                    context.lang,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        initialValue:
                                            '${active.exercises[i].sets}',
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: context.tr(
                                            'Подходы',
                                            'Sets',
                                          ),
                                        ),
                                        onChanged: (String value) {
                                          final int? parsed = int.tryParse(
                                            value,
                                          );
                                          if (parsed != null && parsed > 0) {
                                            _changeExercise(
                                              active,
                                              i,
                                              active.exercises[i].copyWith(
                                                sets: parsed,
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextFormField(
                                        initialValue:
                                            '${active.exercises[i].reps}',
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: context.tr(
                                            'Повторения',
                                            'Reps',
                                          ),
                                        ),
                                        onChanged: (String value) {
                                          final int? parsed = int.tryParse(
                                            value,
                                          );
                                          if (parsed != null && parsed > 0) {
                                            _changeExercise(
                                              active,
                                              i,
                                              active.exercises[i].copyWith(
                                                reps: parsed,
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: () => _finishWithEmotion(active),
                          icon: const Icon(Icons.check_circle_outline),
                          label: Text(
                            context.tr(
                              'Завершить тренировку',
                              'Finish workout',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (active != null) const SizedBox(height: 12),
          Text(
            context.tr('История тренировок', 'Workout history'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (widget.completedWorkouts.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  context.tr(
                    'Пока нет завершенных тренировок',
                    'No completed workouts yet',
                  ),
                ),
              ),
            ),
          for (final CompletedWorkout w in widget.completedWorkouts)
            Card(
              child: ExpansionTile(
                title: Text(
                  '${w.emotion.emoji} ${w.emotion.labelFor(context.lang)}',
                ),
                subtitle: Text(
                  '${_fmtDate(w.completedAt)} • ${_fmtDuration(w.durationSeconds)} • ${w.exercises.length} ${context.tr('упражнений', 'exercises')}',
                ),
                children: [
                  for (final PlannedExercise ex in w.exercises)
                    ListTile(
                      dense: true,
                      title: Text(
                        _exerciseNameForLanguage(ex.name, context.lang),
                      ),
                      subtitle: Text(
                        '${context.tr('Подходы', 'Sets')}: ${ex.sets}, ${context.tr('Повторения', 'Reps')}: ${ex.reps}',
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _BurnTargetCard extends StatelessWidget {
  const _BurnTargetCard({
    required this.burnedCalories,
    required this.targetCalories,
    required this.totalWorkouts,
  });

  final double burnedCalories;
  final int targetCalories;
  final int totalWorkouts;

  @override
  Widget build(BuildContext context) {
    final double progress = targetCalories == 0
        ? 0
        : (burnedCalories / targetCalories).clamp(0.0, 1.0);
    final int remaining = max(0, targetCalories - burnedCalories.round());
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1118),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2478E8).withValues(alpha: 0.20),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BurnLegendLine(
                    color: const Color(0xFFECFF6B),
                    value:
                        '${targetCalories.toString()} ${context.tr('Ккал', 'kcal')}',
                    label: context.tr('цель сжигания', 'burn target'),
                  ),
                  const SizedBox(height: 12),
                  _BurnLegendLine(
                    color: const Color(0xFFB89CFF),
                    value:
                        '${burnedCalories.round()} ${context.tr('Ккал', 'kcal')}',
                    label: context.tr('сожжено сегодня', 'burned today'),
                  ),
                  const SizedBox(height: 12),
                  _BurnLegendLine(
                    color: const Color(0xFF83A7FF),
                    value: '$remaining ${context.tr('Ккал', 'kcal')}',
                    label: context.tr('осталось', 'remaining'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${context.tr('Всего тренировок', 'Total workouts')}: $totalWorkouts',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.70),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 154,
              height: 154,
              child: _CalorieProgressRing(
                progress: progress,
                burnedCalories: burnedCalories.round(),
                targetCalories: targetCalories,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BurnLegendLine extends StatelessWidget {
  const _BurnLegendLine({
    required this.color,
    required this.value,
    required this.label,
  });

  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.60),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CalorieProgressRing extends StatelessWidget {
  const _CalorieProgressRing({
    required this.progress,
    required this.burnedCalories,
    required this.targetCalories,
  });

  final double progress;
  final int burnedCalories;
  final int targetCalories;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox.expand(
          child: CircularProgressIndicator(
            value: 1,
            strokeWidth: 20,
            color: const Color(0xFF242834),
          ),
        ),
        SizedBox.expand(
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 20,
            strokeCap: StrokeCap.round,
            color: const Color(0xFFECFF6B),
            backgroundColor: const Color(0xFF9B7CFF),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF0D1118),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: SizedBox(
            width: 88,
            height: 88,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  burnedCalories.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                Text(
                  'из $targetCalories',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text(
                  'Ккал',
                  style: TextStyle(
                    color: Color(0xFFECFF6B),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WorkoutPresetCard extends StatelessWidget {
  const _WorkoutPresetCard({required this.preset, required this.onTap});

  final _WorkoutPreset preset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLanguage language = context.lang;
    return SizedBox(
      width: 250,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: preset.accent.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [
                preset.accent.withValues(alpha: 0.78),
                const Color(0xFF201C30),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  left: -18,
                  bottom: -10,
                  child: Icon(
                    preset.figureIcon,
                    size: 124,
                    color: Colors.white.withValues(alpha: 0.34),
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 10,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF17171C),
                        width: 3,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${preset.minutes}\n${context.tr('мин', 'min')}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF17171C),
                        fontSize: 11,
                        height: 0.95,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 150,
                        child: Text(
                          preset.titleFor(language),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF17171C),
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Align(
                        alignment: Alignment.centerRight,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF191727,
                            ).withValues(alpha: 0.46),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Text(
                              '${preset.tagFor(language)}  ${preset.exercises.length} ${context.tr('упр.', 'ex.')}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: 172,
                          child: Text(
                            preset.exercises
                                .take(3)
                                .map(
                                  (PlannedExercise e) =>
                                      _exerciseNameForLanguage(
                                        e.name,
                                        language,
                                      ),
                                )
                                .join(' / '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanDialogResult {
  const _PlanDialogResult(this.exerciseNames, this.date);

  final List<String> exerciseNames;
  final DateTime date;
}

class _WorkoutCalendarSheet extends StatefulWidget {
  const _WorkoutCalendarSheet({
    required this.plannedWorkouts,
    required this.completedWorkouts,
    required this.onDateTap,
  });

  final List<PlannedWorkout> plannedWorkouts;
  final List<CompletedWorkout> completedWorkouts;
  final ValueChanged<DateTime> onDateTap;

  @override
  State<_WorkoutCalendarSheet> createState() => _WorkoutCalendarSheetState();
}

class _WorkoutCalendarSheetState extends State<_WorkoutCalendarSheet> {
  late DateTime _displayedMonth;

  DateTime _normalized(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _displayedMonth = DateTime(now.year, now.month, 1);
  }

  String _monthLabel(DateTime date, AppLanguage language) {
    const List<String> monthNamesRu = <String>[
      'Январь',
      'Февраль',
      'Март',
      'Апрель',
      'Май',
      'Июнь',
      'Июль',
      'Август',
      'Сентябрь',
      'Октябрь',
      'Ноябрь',
      'Декабрь',
    ];
    const List<String> monthNamesEn = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final List<String> monthNames = language == AppLanguage.en
        ? monthNamesEn
        : monthNamesRu;
    return '${monthNames[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final DateTime monthStart = DateTime(
      _displayedMonth.year,
      _displayedMonth.month,
      1,
    );
    final int daysInMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + 1,
      0,
    ).day;
    final int leading = monthStart.weekday - 1;
    final int totalCells = ((leading + daysInMonth + 6) ~/ 7) * 7;
    final AppLanguage language = context.lang;

    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.9,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('Календарь тренировок', 'Workout calendar'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr('Предыдущий месяц', 'Previous month'),
                    onPressed: () {
                      setState(() {
                        _displayedMonth = DateTime(
                          _displayedMonth.year,
                          _displayedMonth.month - 1,
                          1,
                        );
                      });
                    },
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text(_monthLabel(_displayedMonth, language)),
                  IconButton(
                    tooltip: context.tr('Следующий месяц', 'Next month'),
                    onPressed: () {
                      setState(() {
                        _displayedMonth = DateTime(
                          _displayedMonth.year,
                          _displayedMonth.month + 1,
                          1,
                        );
                      });
                    },
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _LegendTag(
                    color: Colors.green.shade500,
                    text: context.tr('Прошедшая', 'Completed'),
                  ),
                  _LegendTag(
                    color: Colors.blue.shade500,
                    text: context.tr('Будущая', 'Upcoming'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: GridView.builder(
                  itemCount: totalCells,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                  ),
                  itemBuilder: (BuildContext context, int index) {
                    final int dayNumber = index - leading + 1;
                    if (dayNumber < 1 || dayNumber > daysInMonth) {
                      return const SizedBox.shrink();
                    }
                    final DateTime day = DateTime(
                      _displayedMonth.year,
                      _displayedMonth.month,
                      dayNumber,
                    );
                    final DateTime normalized = _normalized(day);
                    final bool hasPlanned = widget.plannedWorkouts.any(
                      (PlannedWorkout p) =>
                          _sameDay(_normalized(p.plannedDate), normalized),
                    );
                    final bool hasCompleted = widget.completedWorkouts.any(
                      (CompletedWorkout c) =>
                          _sameDay(_normalized(c.completedAt), normalized),
                    );
                    Color? marker;
                    if (hasCompleted) {
                      marker = Colors.green.shade500;
                    } else if (hasPlanned &&
                        normalized.isAfter(_normalized(now))) {
                      marker = Colors.blue.shade500;
                    } else if (hasPlanned) {
                      marker = Colors.green.shade300;
                    }
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => widget.onDateTap(day),
                      child: Container(
                        decoration: BoxDecoration(
                          color: marker?.withValues(alpha: 0.18),
                          border: Border.all(color: marker ?? Colors.black12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '$dayNumber',
                            style: TextStyle(
                              color: marker,
                              fontWeight: marker != null
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyPlaceholderScreen extends StatelessWidget {
  const EmptyPlaceholderScreen({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class FoodScreen extends StatefulWidget {
  const FoodScreen({
    super.key,
    required this.profile,
    required this.entries,
    required this.onChanged,
  });

  final UserProfile profile;
  final List<FoodEntry> entries;
  final Future<void> Function(List<FoodEntry> entries) onChanged;

  @override
  State<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends State<FoodScreen> {
  static final RegExp _decimalRegex = RegExp(r'^\d*([.,]\d*)?$');
  static const int _maxWaterMlPerDay = 6000;
  static const List<String> _food101Classes = <String>[
    'apple_pie',
    'baby_back_ribs',
    'baklava',
    'beef_carpaccio',
    'beef_tartare',
    'beet_salad',
    'beignets',
    'bibimbap',
    'bread_pudding',
    'breakfast_burrito',
    'bruschetta',
    'caesar_salad',
    'cannoli',
    'caprese_salad',
    'carrot_cake',
    'ceviche',
    'cheesecake',
    'cheese_plate',
    'chicken_curry',
    'chicken_quesadilla',
    'chicken_wings',
    'chocolate_cake',
    'chocolate_mousse',
    'churros',
    'clam_chowder',
    'club_sandwich',
    'crab_cakes',
    'creme_brulee',
    'croque_madame',
    'cup_cakes',
    'deviled_eggs',
    'donuts',
    'dumplings',
    'edamame',
    'eggs_benedict',
    'escargots',
    'falafel',
    'filet_mignon',
    'fish_and_chips',
    'foie_gras',
    'french_fries',
    'french_onion_soup',
    'french_toast',
    'fried_calamari',
    'fried_rice',
    'frozen_yogurt',
    'garlic_bread',
    'gnocchi',
    'greek_salad',
    'grilled_cheese_sandwich',
    'grilled_salmon',
    'guacamole',
    'gyoza',
    'hamburger',
    'hot_and_sour_soup',
    'hot_dog',
    'huevos_rancheros',
    'hummus',
    'ice_cream',
    'lasagna',
    'lobster_bisque',
    'lobster_roll_sandwich',
    'macaroni_and_cheese',
    'macarons',
    'miso_soup',
    'mussels',
    'nachos',
    'omelette',
    'onion_rings',
    'oysters',
    'pad_thai',
    'paella',
    'pancakes',
    'panna_cotta',
    'peking_duck',
    'pho',
    'pizza',
    'pork_chop',
    'poutine',
    'prime_rib',
    'pulled_pork_sandwich',
    'ramen',
    'ravioli',
    'red_velvet_cake',
    'risotto',
    'samosa',
    'sashimi',
    'scallops',
    'seaweed_salad',
    'shrimp_and_grits',
    'spaghetti_bolognese',
    'spaghetti_carbonara',
    'spring_rolls',
    'steak',
    'strawberry_shortcake',
    'sushi',
    'tacos',
    'takoyaki',
    'tiramisu',
    'tuna_tartare',
    'waffles',
  ];
  static const Map<
    String,
    (double kcal, double protein, double fat, double carbs)
  >
  _presetMeals = <String, (double, double, double, double)>{
    'Куриная грудка с рисом': (520, 42, 8, 68),
    'Овсянка с бананом': (360, 12, 6, 64),
    'Омлет с овощами': (280, 20, 18, 8),
    'Творог с ягодами': (310, 28, 10, 22),
    'Лосось с картофелем': (610, 38, 28, 46),
  };
  final ImagePicker _imagePicker = ImagePicker();
  Interpreter? _foodModel;
  Interpreter? _nutritionModel;
  bool _modelsLoading = true;
  bool _inferenceLoading = false;
  String? _visionError;
  XFile? _lastCapturedPhoto;
  _FoodVisionResult? _visionResult;
  bool get _visionSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void initState() {
    super.initState();
    _loadVisionModels();
  }

  @override
  void dispose() {
    _foodModel?.close();
    _nutritionModel?.close();
    super.dispose();
  }

  double? _parseDecimal(String value, [double? fallback]) {
    return double.tryParse(value.trim().replaceAll(',', '.')) ?? fallback;
  }

  void _disposeTextControllersAfterRouteExit(
    List<TextEditingController> controllers,
  ) {
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      for (final TextEditingController controller in controllers) {
        controller.dispose();
      }
    });
  }

  Future<void> _loadVisionModels() async {
    if (!_visionSupported) {
      setState(() {
        _modelsLoading = false;
        _visionError = 'ML-распознавание доступно только на Android/iOS';
      });
      return;
    }
    try {
      final Interpreter foodModel = await Interpreter.fromAsset(
        'assets/models/food_model.tflite',
      );
      final Interpreter nutritionModel = await Interpreter.fromAsset(
        'assets/models/nutrition_model.tflite',
      );
      if (!mounted) return;
      setState(() {
        _foodModel = foodModel;
        _nutritionModel = nutritionModel;
        _modelsLoading = false;
        _visionError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _modelsLoading = false;
        _visionError = 'Не удалось загрузить ML-модели: $error';
      });
    }
  }

  List<double> _preprocessImage(File file) {
    final img.Image? decoded = img.decodeImage(file.readAsBytesSync());
    if (decoded == null) {
      throw Exception('Невозможно декодировать изображение');
    }
    final img.Image resized = img.copyResize(decoded, width: 224, height: 224);
    final List<double> chw = List<double>.filled(3 * 224 * 224, 0);
    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        final img.Pixel pixel = resized.getPixel(x, y);
        double r = pixel.r / 255.0;
        double g = pixel.g / 255.0;
        double b = pixel.b / 255.0;
        r = (r - 0.485) / 0.229;
        g = (g - 0.456) / 0.224;
        b = (b - 0.406) / 0.225;
        final int idx = y * 224 + x;
        chw[idx] = r;
        chw[224 * 224 + idx] = g;
        chw[2 * 224 * 224 + idx] = b;
      }
    }
    return chw;
  }

  dynamic _newTensorBuffer(List<int> shape) {
    if (shape.isEmpty) return 0.0;
    final int size = shape.first;
    if (shape.length == 1) {
      return List<double>.filled(size, 0);
    }
    return List<dynamic>.generate(
      size,
      (_) => _newTensorBuffer(shape.sublist(1)),
    );
  }

  List<double> _flattenToDoubleList(dynamic value) {
    if (value is List) {
      return value
          .expand((dynamic item) => _flattenToDoubleList(item))
          .toList();
    }
    if (value is num) {
      return <double>[value.toDouble()];
    }
    return <double>[];
  }

  double _softmaxConfidence(List<double> logits, int index) {
    if (logits.isEmpty || index < 0 || index >= logits.length) {
      return 0;
    }
    final double maxLogit = logits.reduce(max);
    final List<double> expVals = logits
        .map((double v) => exp(v - maxLogit))
        .toList(growable: false);
    final double sum = expVals.fold(0, (double acc, double v) => acc + v);
    if (sum == 0) return 0;
    return expVals[index] / sum;
  }

  Future<ImageSource?> _pickImageSource() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Сфотографировать'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Выбрать из галереи'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _captureAndInfer() async {
    if (!_visionSupported) {
      _showMessage('Камера и ML доступны только на Android/iOS');
      return;
    }
    if (_modelsLoading) {
      _showMessage('Модели еще загружаются');
      return;
    }
    if (_foodModel == null || _nutritionModel == null) {
      _showMessage('Модели недоступны');
      return;
    }
    final ImageSource? source = await _pickImageSource();
    if (!mounted || source == null) return;
    final XFile? captured = await _imagePicker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 1600,
    );
    if (!mounted || captured == null) return;
    setState(() {
      _inferenceLoading = true;
      _visionError = null;
      _lastCapturedPhoto = captured;
    });
    try {
      final List<double> input = _preprocessImage(File(captured.path));
      final List<List<List<List<double>>>> modelInput = [
        List<List<List<double>>>.generate(
          3,
          (int c) => List<List<double>>.generate(
            224,
            (int y) => List<double>.generate(
              224,
              (int x) => input[c * 224 * 224 + y * 224 + x],
            ),
          ),
        ),
      ];
      final dynamic foodOutput = _newTensorBuffer(
        _foodModel!.getOutputTensor(0).shape,
      );
      final dynamic nutritionOutput = _newTensorBuffer(
        _nutritionModel!.getOutputTensor(0).shape,
      );
      _foodModel!.run(modelInput, foodOutput);
      _nutritionModel!.run(modelInput, nutritionOutput);
      final List<double> foodRaw = _flattenToDoubleList(foodOutput);
      final List<double> nutritionRaw = _flattenToDoubleList(nutritionOutput);
      int bestClassIdx = 0;
      if (foodRaw.isNotEmpty) {
        for (int i = 1; i < foodRaw.length; i++) {
          if (foodRaw[i] > foodRaw[bestClassIdx]) {
            bestClassIdx = i;
          }
        }
      }
      final _FoodVisionResult result = _FoodVisionResult(
        foodLabel: bestClassIdx >= 0 && bestClassIdx < _food101Classes.length
            ? _food101Classes[bestClassIdx]
            : 'Класс #${bestClassIdx + 1}',
        confidence: _softmaxConfidence(foodRaw, bestClassIdx),
        calories: nutritionRaw.isNotEmpty ? max(0, nutritionRaw[0]) : 0,
        protein: nutritionRaw.length > 1 ? max(0, nutritionRaw[1]) : 0,
        fat: nutritionRaw.length > 2 ? max(0, nutritionRaw[2]) : 0,
        carbs: nutritionRaw.length > 3 ? max(0, nutritionRaw[3]) : 0,
      );
      if (!mounted) return;
      setState(() {
        _visionResult = result;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _visionError = 'Ошибка инференса: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _inferenceLoading = false);
      }
    }
  }

  Future<void> _editVisionResult() async {
    final _FoodVisionResult? current = _visionResult;
    if (current == null) return;
    final TextEditingController nameCtrl = TextEditingController(
      text: current.foodLabel,
    );
    final TextEditingController kcalCtrl = TextEditingController(
      text: current.calories.toStringAsFixed(0),
    );
    final TextEditingController proteinCtrl = TextEditingController(
      text: current.protein.toStringAsFixed(1),
    );
    final TextEditingController fatCtrl = TextEditingController(
      text: current.fat.toStringAsFixed(1),
    );
    final TextEditingController carbsCtrl = TextEditingController(
      text: current.carbs.toStringAsFixed(1),
    );
    final _FoodVisionResult? edited = await showDialog<_FoodVisionResult>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Редактировать распознавание'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 360,
              child: Column(
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Название блюда',
                    ),
                  ),
                  TextField(
                    controller: kcalCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(_decimalRegex),
                    ],
                    decoration: const InputDecoration(labelText: 'Калории'),
                  ),
                  TextField(
                    controller: proteinCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(_decimalRegex),
                    ],
                    decoration: const InputDecoration(labelText: 'Белки (г)'),
                  ),
                  TextField(
                    controller: fatCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(_decimalRegex),
                    ],
                    decoration: const InputDecoration(labelText: 'Жиры (г)'),
                  ),
                  TextField(
                    controller: carbsCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(_decimalRegex),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Углеводы (г)',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  current.copyWith(
                    foodLabel: nameCtrl.text.trim().isEmpty
                        ? current.foodLabel
                        : nameCtrl.text.trim(),
                    calories:
                        _parseDecimal(kcalCtrl.text, current.calories) ??
                        current.calories,
                    protein:
                        _parseDecimal(proteinCtrl.text, current.protein) ??
                        current.protein,
                    fat:
                        _parseDecimal(fatCtrl.text, current.fat) ?? current.fat,
                    carbs:
                        _parseDecimal(carbsCtrl.text, current.carbs) ??
                        current.carbs,
                  ),
                );
              },
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );
    _disposeTextControllersAfterRouteExit(<TextEditingController>[
      nameCtrl,
      kcalCtrl,
      proteinCtrl,
      fatCtrl,
      carbsCtrl,
    ]);
    if (edited == null || !mounted) return;
    setState(() => _visionResult = edited);
  }

  Future<void> _applyVisionResultAsFoodEntry() async {
    final _FoodVisionResult? result = _visionResult;
    if (result == null) return;
    final String successMessage = context.tr(
      'Распознанное блюдо добавлено в дневник',
      'Recognized meal added to the diary',
    );
    final List<FoodEntry> list = List<FoodEntry>.from(widget.entries);
    list.add(
      FoodEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        dateIso: _today().toIso8601String(),
        name: result.foodLabel,
        calories: result.calories,
        protein: result.protein,
        fat: result.fat,
        carbs: result.carbs,
        waterMl: 0,
      ),
    );
    await _save(list);
    _showMessage(successMessage);
  }

  DateTime _today() {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _weekStart(DateTime date) =>
      date.subtract(Duration(days: date.weekday - 1));

  String _dayKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _save(List<FoodEntry> entries) async {
    entries.sort((FoodEntry a, FoodEntry b) => b.date.compareTo(a.date));
    await widget.onChanged(entries);
  }

  Future<void> _openFoodForm({FoodEntry? edit}) async {
    DateTime selectedDate = edit?.date ?? _today();
    String? selectedPreset;
    final TextEditingController nameCtrl = TextEditingController(
      text: edit?.name ?? '',
    );
    final TextEditingController kcalCtrl = TextEditingController(
      text: '${edit?.calories ?? 0}',
    );
    final TextEditingController proteinCtrl = TextEditingController(
      text: '${edit?.protein ?? 0}',
    );
    final TextEditingController fatCtrl = TextEditingController(
      text: '${edit?.fat ?? 0}',
    );
    final TextEditingController carbsCtrl = TextEditingController(
      text: '${edit?.carbs ?? 0}',
    );
    final TextEditingController waterCtrl = TextEditingController(
      text: '${edit?.waterMl ?? 0}',
    );

    final FoodEntry? result = await showDialog<FoodEntry>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder:
              (
                BuildContext context,
                void Function(void Function()) setStateDialog,
              ) {
                return AlertDialog(
                  title: Text(
                    edit == null
                        ? context.tr('Добавить прием пищи', 'Add meal')
                        : context.tr('Редактировать запись', 'Edit entry'),
                  ),
                  content: SingleChildScrollView(
                    child: SizedBox(
                      width: 380,
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(context.tr('Дата', 'Date')),
                            subtitle: Text(
                              '${selectedDate.day.toString().padLeft(2, '0')}.${selectedDate.month.toString().padLeft(2, '0')}.${selectedDate.year}',
                            ),
                            trailing: IconButton(
                              onPressed: () async {
                                final DateTime? picked = await showDatePicker(
                                  context: context,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                  initialDate: selectedDate,
                                  locale: Locale(context.lang.name),
                                );
                                if (picked != null) {
                                  setStateDialog(() => selectedDate = picked);
                                }
                              },
                              icon: const Icon(Icons.edit_calendar),
                            ),
                          ),
                          TextField(
                            controller: nameCtrl,
                            decoration: InputDecoration(
                              labelText: context.tr(
                                'Блюдо/напиток',
                                'Food/drink',
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: selectedPreset,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: context.tr('Пресет', 'Preset'),
                            ),
                            items: _presetMeals.keys
                                .map(
                                  (String meal) => DropdownMenuItem<String>(
                                    value: meal,
                                    child: Text(
                                      meal,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (String? value) {
                              if (value == null) return;
                              final (
                                double kcal,
                                double protein,
                                double fat,
                                double carbs,
                              ) = _presetMeals[value]!;
                              setStateDialog(() {
                                selectedPreset = value;
                                nameCtrl.text = value;
                                kcalCtrl.text = kcal.toStringAsFixed(0);
                                proteinCtrl.text = protein.toStringAsFixed(1);
                                fatCtrl.text = fat.toStringAsFixed(1);
                                carbsCtrl.text = carbs.toStringAsFixed(1);
                              });
                            },
                          ),
                          TextField(
                            controller: kcalCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(_decimalRegex),
                            ],
                            decoration: InputDecoration(
                              labelText: context.tr('Калории', 'Calories'),
                            ),
                          ),
                          TextField(
                            controller: proteinCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(_decimalRegex),
                            ],
                            decoration: InputDecoration(
                              labelText: context.tr('Белки (г)', 'Protein (g)'),
                            ),
                          ),
                          TextField(
                            controller: fatCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(_decimalRegex),
                            ],
                            decoration: InputDecoration(
                              labelText: context.tr('Жиры (г)', 'Fat (g)'),
                            ),
                          ),
                          TextField(
                            controller: carbsCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(_decimalRegex),
                            ],
                            decoration: InputDecoration(
                              labelText: context.tr(
                                'Углеводы (г)',
                                'Carbs (g)',
                              ),
                            ),
                          ),
                          TextField(
                            controller: waterCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              labelText: context.tr(
                                'Жидкость (мл)',
                                'Fluid (ml)',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(context.tr('Отмена', 'Cancel')),
                    ),
                    FilledButton(
                      onPressed: () {
                        final int waterMl =
                            (int.tryParse(waterCtrl.text.trim()) ?? 0).clamp(
                              0,
                              _maxWaterMlPerDay,
                            );
                        final FoodEntry next = FoodEntry(
                          id:
                              edit?.id ??
                              DateTime.now().millisecondsSinceEpoch.toString(),
                          dateIso: DateTime(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day,
                          ).toIso8601String(),
                          name: nameCtrl.text.trim().isEmpty
                              ? context.tr('Без названия', 'Untitled')
                              : nameCtrl.text.trim(),
                          calories: _parseDecimal(kcalCtrl.text, 0) ?? 0,
                          protein: _parseDecimal(proteinCtrl.text, 0) ?? 0,
                          fat: _parseDecimal(fatCtrl.text, 0) ?? 0,
                          carbs: _parseDecimal(carbsCtrl.text, 0) ?? 0,
                          waterMl: waterMl,
                        );
                        Navigator.pop(context, next);
                      },
                      child: Text(context.tr('Сохранить', 'Save')),
                    ),
                  ],
                );
              },
        );
      },
    );

    _disposeTextControllersAfterRouteExit(<TextEditingController>[
      nameCtrl,
      kcalCtrl,
      proteinCtrl,
      fatCtrl,
      carbsCtrl,
      waterCtrl,
    ]);

    if (result == null) return;
    final List<FoodEntry> list = List<FoodEntry>.from(widget.entries);
    final int idx = list.indexWhere((FoodEntry e) => e.id == result.id);
    if (idx >= 0) {
      list[idx] = result;
    } else {
      list.add(result);
    }
    await _save(list);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final DateTime today = _today();
    final DateTime weekStart = _weekStart(today);
    final DateTime weekEnd = weekStart.add(const Duration(days: 6));

    final List<FoodEntry> todayEntries = widget.entries
        .where((FoodEntry e) => _sameDay(e.date, today))
        .toList();
    final List<FoodEntry> weekEntries = widget.entries
        .where(
          (FoodEntry e) =>
              !e.date.isBefore(weekStart) && !e.date.isAfter(weekEnd),
        )
        .toList();
    final Map<String, double> proteinByDay = <String, double>{};
    for (final FoodEntry entry in widget.entries) {
      final String key = _dayKey(entry.date);
      proteinByDay[key] = (proteinByDay[key] ?? 0) + entry.protein;
    }

    double sumCalories(List<FoodEntry> list) =>
        list.fold(0, (double p, FoodEntry e) => p + e.calories);
    double sumProtein(List<FoodEntry> list) =>
        list.fold(0, (double p, FoodEntry e) => p + e.protein);
    double sumFat(List<FoodEntry> list) =>
        list.fold(0, (double p, FoodEntry e) => p + e.fat);
    double sumCarbs(List<FoodEntry> list) =>
        list.fold(0, (double p, FoodEntry e) => p + e.carbs);
    int sumWater(List<FoodEntry> list) =>
        list.fold(0, (int p, FoodEntry e) => p + e.waterMl);
    final _NutritionTargets targets = _nutritionTargetsFor(widget.profile);
    final double todayCalories = sumCalories(todayEntries);
    final double todayProtein = sumProtein(todayEntries);
    final double todayFat = sumFat(todayEntries);
    final double todayCarbs = sumCarbs(todayEntries);

    return Scaffold(
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'food_camera_fab',
            onPressed: _inferenceLoading || !_visionSupported
                ? null
                : _captureAndInfer,
            icon: _inferenceLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.photo_camera_outlined),
            label: Text(context.tr('Камера', 'Camera')),
          ),
          const SizedBox(width: 10),
          FloatingActionButton(
            heroTag: 'food_add_fab',
            onPressed: () => _openFoodForm(),
            child: const Icon(Icons.add),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _NutritionGoalCard(
            targets: targets,
            calories: todayCalories,
            protein: todayProtein,
            fat: todayFat,
            carbs: todayCarbs,
          ),
          const SizedBox(height: 12),
          if (_modelsLoading)
            Card(
              child: ListTile(
                leading: const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                title: Text(
                  context.tr('Загрузка ML-моделей...', 'Loading ML models...'),
                ),
              ),
            ),
          if (_visionError != null)
            Card(
              color: Colors.red.withValues(alpha: 0.08),
              child: ListTile(
                leading: const Icon(Icons.error_outline, color: Colors.red),
                title: Text(
                  context.tr('Ошибка распознавания', 'Recognition error'),
                ),
                subtitle: Text(_visionError!),
              ),
            ),
          if (_visionResult != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(context.tr('Результат AI', 'AI result')),
                        ),
                        TextButton.icon(
                          onPressed: _editVisionResult,
                          icon: const Icon(Icons.edit_outlined),
                          label: Text(context.tr('Редактировать', 'Edit')),
                        ),
                      ],
                    ),
                    if (_lastCapturedPhoto != null) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(_lastCapturedPhoto!.path),
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      _visionResult!.foodLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${context.tr('Уверенность', 'Confidence')}: ${(_visionResult!.confidence * 100).toStringAsFixed(1)}%',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${context.tr('Калории', 'Calories')} ${_visionResult!.calories.toStringAsFixed(0)} • '
                      '${context.tr('Белки', 'Protein')} ${_visionResult!.protein.toStringAsFixed(1)} • '
                      '${context.tr('Жиры', 'Fat')} ${_visionResult!.fat.toStringAsFixed(1)} • '
                      '${context.tr('Углеводы', 'Carbs')} ${_visionResult!.carbs.toStringAsFixed(1)}',
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _applyVisionResultAsFoodEntry,
                        icon: const Icon(Icons.add_task_outlined),
                        label: Text(
                          context.tr('Добавить в дневник', 'Add to diary'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                context.tr('Сегодня', 'Today'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF063F3E),
                ),
              ),
            ],
          ),
          Card(
            child: ListTile(
              title: Text(context.tr('Сегодня', 'Today')),
              subtitle: Text(
                '${context.tr('Калории', 'Calories')} ${sumCalories(todayEntries).toStringAsFixed(0)} • ${context.tr('Белки', 'Protein')} ${sumProtein(todayEntries).toStringAsFixed(1)} • ${context.tr('Жиры', 'Fat')} ${sumFat(todayEntries).toStringAsFixed(1)} • ${context.tr('Углеводы', 'Carbs')} ${sumCarbs(todayEntries).toStringAsFixed(1)} • ${context.tr('Вода', 'Water')} ${sumWater(todayEntries)} ${context.tr('мл', 'ml')}',
              ),
            ),
          ),
          Card(
            child: ListTile(
              title: Text(context.tr('Неделя', 'Week')),
              subtitle: Text(
                '${context.tr('Калории', 'Calories')} ${sumCalories(weekEntries).toStringAsFixed(0)} • ${context.tr('Белки', 'Protein')} ${sumProtein(weekEntries).toStringAsFixed(1)} • ${context.tr('Жиры', 'Fat')} ${sumFat(weekEntries).toStringAsFixed(1)} • ${context.tr('Углеводы', 'Carbs')} ${sumCarbs(weekEntries).toStringAsFixed(1)} • ${context.tr('Вода', 'Water')} ${sumWater(weekEntries)} ${context.tr('мл', 'ml')}',
              ),
            ),
          ),
          const SizedBox(height: 8),
          _WaterBottlesWidget(
            consumedMl: sumWater(todayEntries).clamp(0, _maxWaterMlPerDay),
            maxMl: _maxWaterMlPerDay,
          ),
          const SizedBox(height: 8),
          _WeeklyFoodCharts(entries: widget.entries),
          const SizedBox(height: 8),
          if (widget.entries.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  context.tr(
                    'Пока нет записей по еде и напиткам',
                    'No food or drink entries yet',
                  ),
                ),
              ),
            ),
          for (final FoodEntry e in widget.entries)
            Card(
              child: ListTile(
                title: Text(e.name),
                subtitle: Text(
                  '${e.date.day.toString().padLeft(2, '0')}.${e.date.month.toString().padLeft(2, '0')}.${e.date.year} • ${e.calories.toStringAsFixed(0)} ${context.tr('ккал', 'kcal')} • ${context.tr('Вода', 'Water')} ${e.waterMl} ${context.tr('мл', 'ml')}',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (String action) async {
                    if (action == 'edit') {
                      await _openFoodForm(edit: e);
                    } else {
                      final List<FoodEntry> list = List<FoodEntry>.from(
                        widget.entries,
                      )..removeWhere((FoodEntry item) => item.id == e.id);
                      await _save(list);
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text(context.tr('Редактировать', 'Edit')),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(context.tr('Удалить', 'Delete')),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _NutritionGoalCard extends StatelessWidget {
  const _NutritionGoalCard({
    required this.targets,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
  });

  final _NutritionTargets targets;
  final double calories;
  final double protein;
  final double fat;
  final double carbs;

  @override
  Widget build(BuildContext context) {
    final double calorieProgress = (calories / targets.calories).clamp(
      0.0,
      1.0,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF072C2D),
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [Color(0xFF062A2B), Color(0xFF0EB9AE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0EB9AE).withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('Цель питания на день', 'Daily nutrition goal'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${calories.toStringAsFixed(0)} / ${targets.calories} ${context.tr('ккал', 'kcal')}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 12,
                value: calorieProgress,
                backgroundColor: Colors.white.withValues(alpha: 0.20),
                color: const Color(0xFFFFB84D),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MacroProgressPill(
                    label: context.tr('Белки', 'Protein'),
                    value: protein,
                    target: targets.protein.toDouble(),
                    color: const Color(0xFFB89CFF),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MacroProgressPill(
                    label: context.tr('Жиры', 'Fat'),
                    value: fat,
                    target: targets.fat.toDouble(),
                    color: const Color(0xFFFFB84D),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MacroProgressPill(
                    label: context.tr('Углеводы', 'Carbs'),
                    value: carbs,
                    target: targets.carbs.toDouble(),
                    color: const Color(0xFF83A7FF),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroProgressPill extends StatelessWidget {
  const _MacroProgressPill({
    required this.label,
    required this.value,
    required this.target,
    required this.color,
  });

  final String label;
  final double value;
  final double target;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final double progress = target == 0 ? 0 : (value / target).clamp(0.0, 1.0);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${value.toStringAsFixed(0)}/${target.toStringAsFixed(0)}г',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaterBottlesWidget extends StatelessWidget {
  const _WaterBottlesWidget({required this.consumedMl, required this.maxMl});

  final int consumedMl;
  final int maxMl;

  @override
  Widget build(BuildContext context) {
    const int bottleMl = 1500;
    final int bottles = maxMl ~/ bottleMl;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Вода: $consumedMl мл из $maxMl мл'),
            const SizedBox(height: 8),
            Row(
              children: List<Widget>.generate(bottles, (int index) {
                final int start = index * bottleMl;
                final double fill = ((consumedMl - start) / bottleMl).clamp(
                  0.0,
                  1.0,
                );
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 70,
                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              Container(
                                width: 24,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.blueGrey),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              FractionallySizedBox(
                                heightFactor: fill,
                                child: Container(
                                  width: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade400,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text('1.5л', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyFoodCharts extends StatelessWidget {
  const _WeeklyFoodCharts({required this.entries});

  final List<FoodEntry> entries;

  DateTime _weekStart(DateTime date) =>
      date.subtract(Duration(days: date.weekday - 1));

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final DateTime start = _weekStart(now);
    final List<double> water = List<double>.filled(7, 0);
    final List<double> kcal = List<double>.filled(7, 0);
    for (final FoodEntry e in entries) {
      final DateTime d = DateTime(e.date.year, e.date.month, e.date.day);
      if (d.isBefore(start) || d.isAfter(start.add(const Duration(days: 6)))) {
        continue;
      }
      final int idx = d.difference(start).inDays;
      water[idx] += e.waterMl.toDouble();
      kcal[idx] += e.calories;
    }
    return Column(
      children: [
        _SimpleWeekBarChart(
          title: 'Вода за неделю (мл)',
          values: water,
          color: Colors.blue,
        ),
        const SizedBox(height: 8),
        _SimpleWeekBarChart(
          title: 'Калории за неделю',
          values: kcal,
          color: Colors.deepOrange,
        ),
      ],
    );
  }
}

class _SimpleWeekBarChart extends StatelessWidget {
  const _SimpleWeekBarChart({
    required this.title,
    required this.values,
    required this.color,
  });

  final String title;
  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final double maxValue = max(1, values.reduce(max));
    const List<String> week = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List<Widget>.generate(7, (int i) {
                  final double ratio = (values[i] / maxValue).clamp(0.0, 1.0);
                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: ratio,
                              child: Container(
                                width: 18,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(week[i], style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.appData,
    required this.onProfileUpdated,
    required this.onSettingsUpdated,
    required this.onDeleteProfile,
  });

  final AppData appData;
  final Future<void> Function(UserProfile profile) onProfileUpdated;
  final Future<void> Function(AppSettings settings) onSettingsUpdated;
  final Future<void> Function() onDeleteProfile;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _updatingAvatar = false;

  String _tr(String ru, String en) {
    return widget.appData.settings.language == AppLanguage.en ? en : ru;
  }

  String _dayKey(DateTime date) {
    final String mm = date.month.toString().padLeft(2, '0');
    final String dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }

  Future<PermissionStatus> _requestMediaPermission(ImageSource source) async {
    if (source == ImageSource.camera) {
      return Permission.camera.request();
    }
    if (Platform.isAndroid) {
      final PermissionStatus photos = await Permission.photos.request();
      if (photos.isGranted) {
        return photos;
      }
      return Permission.storage.request();
    }
    return Permission.photos.request();
  }

  Future<String> _persistAvatar(String sourcePath) async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    final Directory avatarsDir = Directory('${appDir.path}/avatars');
    if (!await avatarsDir.exists()) {
      await avatarsDir.create(recursive: true);
    }
    final String ext = sourcePath.contains('.')
        ? sourcePath.split('.').last
        : 'jpg';
    final String targetPath =
        '${avatarsDir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final File copied = await File(sourcePath).copy(targetPath);
    return copied.path;
  }

  Future<void> _pickAvatar(ImageSource source) async {
    setState(() => _updatingAvatar = true);
    try {
      final PermissionStatus status = await _requestMediaPermission(source);
      if (!status.isGranted) {
        _showMessage('Нет разрешения на доступ к фото/камере');
        return;
      }
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
      );
      if (picked == null) {
        return;
      }
      final String savedPath = await _persistAvatar(picked.path);
      final UserProfile updated = widget.appData.profile.copyWith(
        avatarPath: savedPath,
      );
      await widget.onProfileUpdated(updated);
    } finally {
      if (mounted) {
        setState(() => _updatingAvatar = false);
      }
    }
  }

  Future<void> _showAvatarMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Выбрать из галереи'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _pickAvatar(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Сделать фото'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _pickAvatar(ImageSource.camera);
                },
              ),
              if (widget.appData.profile.avatarPath != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Удалить фото'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await widget.onProfileUpdated(
                      widget.appData.profile.copyWith(clearAvatar: true),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  List<_AchievementItem> _buildWorkoutAchievements() {
    final int workoutCount = widget.appData.completedWorkouts.length;
    return <_AchievementItem>[
      _AchievementItem(
        title: _tr('Первые шаги', 'First steps'),
        description: _tr(
          'Сделать 1 физическую тренировку',
          'Complete 1 strength workout',
        ),
        done: workoutCount >= 1,
      ),
      _AchievementItem(
        title: _tr('Разогнался', 'Getting momentum'),
        description: _tr(
          'Сделать 10 физических тренировок',
          'Complete 10 strength workouts',
        ),
        done: workoutCount >= 10,
      ),
      _AchievementItem(
        title: _tr('Машина', 'Machine'),
        description: _tr(
          'Сделать 100 физических тренировок',
          'Complete 100 strength workouts',
        ),
        done: workoutCount >= 100,
      ),
    ];
  }

  List<_AchievementItem> _buildRunAchievements() {
    final int runs = widget.appData.runs.length;
    final double runKm = widget.appData.runs.fold<double>(
      0,
      (double sum, RunEntry run) => sum + run.distanceKm,
    );
    return <_AchievementItem>[
      _AchievementItem(
        title: _tr('Беговой старт', 'Running start'),
        description: _tr('Завершить 1 пробежку', 'Finish 1 run'),
        done: runs >= 1,
      ),
      _AchievementItem(
        title: _tr('Ритм', 'Rhythm'),
        description: _tr('Завершить 10 пробежек', 'Finish 10 runs'),
        done: runs >= 10,
      ),
      _AchievementItem(
        title: _tr('Дистанция', 'Distance'),
        description: _tr('Завершить 50 пробежек', 'Finish 50 runs'),
        done: runs >= 50,
      ),
      _AchievementItem(
        title: '42.195',
        description: _tr(
          'Набрать марафонскую дистанцию суммарно',
          'Reach a marathon distance in total',
        ),
        done: runKm >= 42.195,
      ),
    ];
  }

  String _formatHeight(UserProfile profile) {
    if (widget.appData.settings.unitSystem == UnitSystem.metric) {
      return '${profile.heightCm.toStringAsFixed(0)} см';
    }
    final int totalInches = (profile.heightCm / 2.54).round();
    final int feet = totalInches ~/ 12;
    final int inches = totalInches % 12;
    return '$feet ft $inches in';
  }

  String _formatWeight(UserProfile profile) {
    if (widget.appData.settings.unitSystem == UnitSystem.metric) {
      return '${profile.weightKg.toStringAsFixed(1)} кг';
    }
    return '${(profile.weightKg * 2.20462).toStringAsFixed(1)} lb';
  }

  List<Map<String, dynamic>> _achievementJson() {
    return <Map<String, dynamic>>[
      for (final _AchievementItem item in _buildWorkoutAchievements())
        <String, dynamic>{
          'group': 'workouts',
          'title': item.title,
          'description': item.description,
          'done': item.done,
        },
      for (final _AchievementItem item in _buildRunAchievements())
        <String, dynamic>{
          'group': 'runs',
          'title': item.title,
          'description': item.description,
          'done': item.done,
        },
    ];
  }

  Future<void> _openSettings() async {
    AppLanguage language = widget.appData.settings.language;
    UnitSystem unitSystem = widget.appData.settings.unitSystem;
    final AppSettings? result = await showDialog<AppSettings>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder:
              (
                BuildContext context,
                void Function(void Function()) setStateDialog,
              ) {
                return AlertDialog(
                  title: Text(_tr('Настройки приложения', 'App settings')),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<UnitSystem>(
                        initialValue: unitSystem,
                        decoration: InputDecoration(
                          labelText: _tr('Система единиц', 'Unit system'),
                          prefixIcon: const Icon(Icons.straighten),
                        ),
                        items: UnitSystem.values
                            .map(
                              (UnitSystem value) => DropdownMenuItem(
                                value: value,
                                child: Text(value.labelFor(language)),
                              ),
                            )
                            .toList(),
                        onChanged: (UnitSystem? value) {
                          if (value != null) {
                            setStateDialog(() => unitSystem = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<AppLanguage>(
                        initialValue: language,
                        decoration: InputDecoration(
                          labelText: _tr('Язык', 'Language'),
                          prefixIcon: const Icon(Icons.language),
                        ),
                        items: AppLanguage.values
                            .map(
                              (AppLanguage value) => DropdownMenuItem(
                                value: value,
                                child: Text(value.label),
                              ),
                            )
                            .toList(),
                        onChanged: (AppLanguage? value) {
                          if (value != null) {
                            setStateDialog(() => language = value);
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _tr(
                          'Язык применяется к основным экранам, профилю, Kaze и системным действиям. Настройка сохраняется в Firestore.',
                          'Language is applied to core screens, profile, Kaze, and system actions. The setting is saved in Firestore.',
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(_tr('Отмена', 'Cancel')),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(
                        context,
                        AppSettings(language: language, unitSystem: unitSystem),
                      ),
                      child: Text(_tr('Сохранить', 'Save')),
                    ),
                  ],
                );
              },
        );
      },
    );
    if (result == null) return;
    await widget.onSettingsUpdated(result);
    _showMessage(_tr('Настройки сохранены', 'Settings saved'));
  }

  Future<void> _exportData() async {
    try {
      final Directory root = await getApplicationDocumentsDirectory();
      final String stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final Directory dir = Directory('${root.path}/kaze_export_$stamp');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      const JsonEncoder encoder = JsonEncoder.withIndent('  ');
      final File workoutsFile = File('${dir.path}/kaze_workouts.json');
      final File runsFile = File('${dir.path}/kaze_runs.json');
      final File nutritionFile = File('${dir.path}/kaze_nutrition.json');
      await workoutsFile.writeAsString(
        encoder.convert(<String, dynamic>{
          'profile': widget.appData.profile.toJson(),
          'settings': widget.appData.settings.toJson(),
          'plannedWorkouts': widget.appData.plannedWorkouts
              .map((PlannedWorkout e) => e.toJson())
              .toList(),
          'completedWorkouts': widget.appData.completedWorkouts
              .map((CompletedWorkout e) => e.toJson())
              .toList(),
          'rememberedExerciseSets': widget.appData.rememberedExerciseSets,
          'achievements': _achievementJson(),
        }),
      );
      await runsFile.writeAsString(
        encoder.convert(<String, dynamic>{
          'runDays': widget.appData.runDays,
          'runs': widget.appData.runs.map((RunEntry e) => e.toJson()).toList(),
        }),
      );
      await nutritionFile.writeAsString(
        encoder.convert(<String, dynamic>{
          'foodEntries': widget.appData.foodEntries
              .map((FoodEntry e) => e.toJson())
              .toList(),
        }),
      );
      await _showExportReadyDialog(dir, <File>[
        workoutsFile,
        runsFile,
        nutritionFile,
      ]);
    } catch (error) {
      _showMessage(
        _tr(
          'Не удалось экспортировать данные: $error',
          'Could not export data: $error',
        ),
      );
    }
  }

  Future<void> _showExportReadyDialog(Directory dir, List<File> files) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(_tr('Экспорт готов', 'Export ready')),
          content: Text(
            _tr(
              'Файлы созданы. На эмуляторе папка приложения приватная, поэтому используй кнопку ниже, чтобы открыть системное меню и сохранить/отправить файлы.\n\nПуть: ${dir.path}',
              'Files are ready. On an emulator, the app folder is private, so use the button below to open the system share sheet and save/send the files.\n\nPath: ${dir.path}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_tr('Закрыть', 'Close')),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await SharePlus.instance.share(
                  ShareParams(
                    title: 'Kaze export',
                    text: _tr('Экспорт данных Kaze', 'Kaze data export'),
                    files: files.map((File file) => XFile(file.path)).toList(),
                  ),
                );
              },
              icon: const Icon(Icons.ios_share_outlined),
              label: Text(_tr('Скачать / отправить', 'Save / share')),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final UserProfile profile = widget.appData.profile;
    final List<_AchievementItem> workoutAchievements =
        _buildWorkoutAchievements();
    final List<_AchievementItem> runAchievements = _buildRunAchievements();
    final String? avatarPath = profile.avatarPath;
    final bool avatarExists =
        avatarPath != null && File(avatarPath).existsSync();
    final ImageProvider<Object>? avatarImage = avatarExists
        ? FileImage(File(avatarPath))
        : null;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundImage: avatarImage,
                    child: !avatarExists
                        ? Text(
                            profile.username.isEmpty
                                ? '?'
                                : profile.username[0].toUpperCase(),
                            style: const TextStyle(fontSize: 28),
                          )
                        : null,
                  ),
                  Positioned(
                    right: -6,
                    bottom: -6,
                    child: IconButton.filledTonal(
                      onPressed: _updatingAvatar ? null : _showAvatarMenu,
                      icon: _updatingAvatar
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.camera_alt_outlined),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.username,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_tr('Цель', 'Goal')}: ${profile.goal.labelFor(widget.appData.settings.language)}',
                    ),
                    Text(
                      '${_tr('Тренировок', 'Workouts')}: ${widget.appData.totalWorkouts}',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: Text(_tr('Настройки приложения', 'App settings')),
            subtitle: Text(
              '${widget.appData.settings.unitSystem.labelFor(widget.appData.settings.language)} • ${widget.appData.settings.language.label}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openSettings,
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.ios_share_outlined),
            title: Text(_tr('Экспорт данных', 'Export data')),
            subtitle: Text(
              _tr(
                'Тренировки, забеги и питание в 3 JSON-файла',
                'Workouts, runs, and nutrition as 3 JSON files',
              ),
            ),
            trailing: const Icon(Icons.download_outlined),
            onTap: _exportData,
          ),
        ),
        const SizedBox(height: 8),
        _ProfileItem(
          label: _tr('Рост', 'Height'),
          value: _formatHeight(profile),
        ),
        _ProfileItem(
          label: _tr('Вес', 'Weight'),
          value: _formatWeight(profile),
        ),
        _ProfileItem(
          label: _tr('Пол', 'Gender'),
          value: profile.gender.labelFor(widget.appData.settings.language),
        ),
        _ProfileItem(label: _tr('Возраст', 'Age'), value: '${profile.age}'),
        _ProfileItem(
          label: _tr('Тренировок в неделю', 'Workouts per week'),
          value: '${profile.workoutsPerWeek}',
        ),
        const SizedBox(height: 16),
        Text(
          _tr('Ачивки: тренировки', 'Achievements: workouts'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        for (final _AchievementItem item in workoutAchievements)
          Card(
            child: ListTile(
              leading: Icon(
                item.done ? Icons.emoji_events : Icons.lock_outline,
                color: item.done ? Colors.amber.shade700 : null,
              ),
              title: Text(item.title),
              subtitle: Text(item.description),
              trailing: Text(
                item.done
                    ? _tr('Получено', 'Unlocked')
                    : _tr('В процессе', 'In progress'),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          _tr('Ачивки: бег', 'Achievements: running'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        for (final _AchievementItem item in runAchievements)
          Card(
            child: ListTile(
              leading: Icon(
                item.done ? Icons.emoji_events : Icons.lock_outline,
                color: item.done ? Colors.amber.shade700 : null,
              ),
              title: Text(item.title),
              subtitle: Text(item.description),
              trailing: Text(
                item.done
                    ? _tr('Получено', 'Unlocked')
                    : _tr('В процессе', 'In progress'),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          _tr('Календарь активности', 'Activity calendar'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _LegendTag(
              color: Colors.green.shade500,
              text: _tr('Тренировка', 'Workout'),
            ),
            _LegendTag(
              color: Colors.blue.shade500,
              text: _tr('Пробежка', 'Run'),
            ),
            _LegendMixedTag(
              text: _tr('И тренировка, и бег', 'Workout and run'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _GithubCalendar(
          workoutDays: widget.appData.workoutDays.toSet(),
          runDays: widget.appData.runDays.toSet(),
          dayKeyBuilder: _dayKey,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: widget.onDeleteProfile,
          icon: const Icon(Icons.delete_outline),
          label: Text(_tr('Удалить аккаунт', 'Delete account')),
        ),
      ],
    );
  }
}

class _ProfileItem extends StatelessWidget {
  const _ProfileItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(title: Text(label), subtitle: Text(value)),
    );
  }
}

class _AchievementItem {
  const _AchievementItem({
    required this.title,
    required this.description,
    required this.done,
  });

  final String title;
  final String description;
  final bool done;
}

class _LegendTag extends StatelessWidget {
  const _LegendTag({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(text),
      ],
    );
  }
}

class _LegendMixedTag extends StatelessWidget {
  const _LegendMixedTag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(12, 12),
          painter: const _ActivityDayCellPainter(
            workout: true,
            run: true,
            background: Colors.transparent,
          ),
        ),
        const SizedBox(width: 6),
        Text(text),
      ],
    );
  }
}

class _GithubCalendar extends StatelessWidget {
  const _GithubCalendar({
    required this.workoutDays,
    required this.runDays,
    required this.dayKeyBuilder,
  });

  final Set<String> workoutDays;
  final Set<String> runDays;
  final String Function(DateTime date) dayKeyBuilder;

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final List<DateTime> days = List<DateTime>.generate(
      84,
      (int i) => now.subtract(Duration(days: 83 - i)),
    );
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: days.map((DateTime day) {
        final String key = dayKeyBuilder(day);
        final bool workout = workoutDays.contains(key);
        final bool run = runDays.contains(key);
        return CustomPaint(
          size: const Size(12, 12),
          painter: _ActivityDayCellPainter(
            workout: workout,
            run: run,
            background: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        );
      }).toList(),
    );
  }
}

class _ActivityDayCellPainter extends CustomPainter {
  const _ActivityDayCellPainter({
    required this.workout,
    required this.run,
    required this.background,
  });

  final bool workout;
  final bool run;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(3),
    );
    canvas.drawRRect(rect, Paint()..color = background);

    if (!workout && !run) return;

    if (workout && run) {
      final ui.Path greenTriangle = ui.Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(0, size.height)
        ..close();
      final ui.Path blueTriangle = ui.Path()
        ..moveTo(size.width, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.save();
      canvas.clipRRect(rect);
      canvas.drawPath(greenTriangle, Paint()..color = Colors.green.shade500);
      canvas.drawPath(blueTriangle, Paint()..color = Colors.blue.shade500);
      canvas.restore();
      return;
    }

    canvas.drawRRect(
      rect,
      Paint()..color = workout ? Colors.green.shade500 : Colors.blue.shade500,
    );
  }

  @override
  bool shouldRepaint(covariant _ActivityDayCellPainter oldDelegate) {
    return oldDelegate.workout != workout ||
        oldDelegate.run != run ||
        oldDelegate.background != background;
  }
}

class RunScreen extends StatefulWidget {
  const RunScreen({
    super.key,
    required this.profile,
    required this.runs,
    required this.onRunSaved,
  });

  final UserProfile profile;
  final List<RunEntry> runs;
  final Future<void> Function(RunEntry run) onRunSaved;

  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen> {
  bool _running = false;
  bool _requesting = false;
  DateTime? _startedAt;
  int _seconds = 0;
  double _distanceKm = 0;
  List<RoutePoint> _points = <RoutePoint>[];
  StreamSubscription<Position>? _positionSub;
  Timer? _timer;

  @override
  void dispose() {
    _positionSub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  String _fmtDate(DateTime dt) {
    final String dd = dt.day.toString().padLeft(2, '0');
    final String mm = dt.month.toString().padLeft(2, '0');
    final String hh = dt.hour.toString().padLeft(2, '0');
    final String min = dt.minute.toString().padLeft(2, '0');
    return '$dd.$mm.${dt.year} $hh:$min';
  }

  String _fmtDuration(int total) {
    final int h = total ~/ 3600;
    final int m = (total % 3600) ~/ 60;
    final int s = total % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _startRun() async {
    final String locationDisabledMessage = context.tr(
      'Включите геолокацию на устройстве',
      'Turn on location services on the device',
    );
    final String locationPermissionMessage = context.tr(
      'Разрешите доступ к геолокации',
      'Allow location access',
    );
    setState(() => _requesting = true);
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMessage(locationDisabledMessage);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage(locationPermissionMessage);
        return;
      }

      _points = <RoutePoint>[];
      _distanceKm = 0;
      _seconds = 0;
      _startedAt = DateTime.now();
      _running = true;

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
        if (mounted) {
          setState(() => _seconds++);
        }
      });

      _positionSub?.cancel();
      _positionSub =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.best,
              distanceFilter: 5,
            ),
          ).listen((Position p) {
            final RoutePoint next = RoutePoint(p.latitude, p.longitude);
            if (_points.isNotEmpty) {
              final RoutePoint prev = _points.last;
              _distanceKm +=
                  Geolocator.distanceBetween(
                    prev.lat,
                    prev.lng,
                    next.lat,
                    next.lng,
                  ) /
                  1000;
            }
            if (mounted) {
              setState(() => _points = <RoutePoint>[..._points, next]);
            } else {
              _points.add(next);
            }
          });
      setState(() {});
    } finally {
      if (mounted) {
        setState(() => _requesting = false);
      }
    }
  }

  Future<void> _stopRun() async {
    _timer?.cancel();
    await _positionSub?.cancel();
    _positionSub = null;
    final RunEntry entry = RunEntry(
      startedAtIso: (_startedAt ?? DateTime.now()).toIso8601String(),
      durationSeconds: _seconds,
      distanceKm: _distanceKm,
      route: _points,
    );
    await widget.onRunSaved(entry);
    if (!mounted) {
      return;
    }
    setState(() {
      _running = false;
      _startedAt = null;
      _seconds = 0;
      _distanceKm = 0;
      _points = <RoutePoint>[];
    });
    _showMessage(context.tr('Пробежка сохранена', 'Run saved'));
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final double totalKm = widget.runs.fold<double>(
      0,
      (double sum, RunEntry run) => sum + run.distanceKm,
    );
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _MarathonStadiumProgress(totalKm: totalKm),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${context.tr('Таймер', 'Timer')}: ${_fmtDuration(_seconds)}',
                ),
                Text(
                  '${context.tr('Дистанция', 'Distance')}: ${_distanceKm.toStringAsFixed(2)} ${context.tr('км', 'km')}',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _running || _requesting ? null : _startRun,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(context.tr('Начать пробежку', 'Start run')),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _running ? _stopRun : null,
                      icon: const Icon(Icons.stop),
                      label: Text(context.tr('Завершить', 'Finish')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.tr('История пробежек', 'Run history'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (widget.runs.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.tr(
                  'Пока нет сохраненных пробежек',
                  'No saved runs yet',
                ),
              ),
            ),
          ),
        for (final RunEntry run in widget.runs)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${context.tr('Дата', 'Date')}: ${_fmtDate(run.startedAt)}',
                  ),
                  Text(
                    '${context.tr('Время', 'Time')}: ${_fmtDuration(run.durationSeconds)}',
                  ),
                  Text(
                    '${context.tr('Километраж', 'Distance')}: ${run.distanceKm.toStringAsFixed(2)} ${context.tr('км', 'km')}',
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _RunMap(route: run.route),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _MarathonStadiumProgress extends StatelessWidget {
  const _MarathonStadiumProgress({required this.totalKm});

  static const double marathonKm = 42.195;
  final double totalKm;

  @override
  Widget build(BuildContext context) {
    final double progress = (totalKm / marathonKm).clamp(0.0, 1.0);
    final double remaining = max(0, marathonKm - totalKm);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF15111F),
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [Color(0xFF17111F), Color(0xFF6D45D8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8C63F6).withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Марафонский стадион', 'Marathon stadium'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${totalKm.toStringAsFixed(3)} ${context.tr('км', 'km')} ${context.tr('из', 'of')} 42.195 ${context.tr('км', 'km')}',
                    style: const TextStyle(
                      color: Color(0xFFFFB84D),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    remaining == 0
                        ? context.tr(
                            'Марафон закрыт. Новый круг начинается дальше.',
                            'Marathon completed. The next lap starts now.',
                          )
                        : context.tr(
                            'Осталось ${remaining.toStringAsFixed(3)} км до марафона',
                            '${remaining.toStringAsFixed(3)} km left to marathon distance',
                          ),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.tr(
                      'Факт: дистанция 42.195 км закрепилась после Олимпиады 1908 года в Лондоне. Забег стартовал у Виндзорского замка и финишировал перед королевской ложей: 26 миль и 385 ярдов.',
                      'Fact: 42.195 km became standard after the 1908 London Olympics. The race started at Windsor Castle and finished in front of the royal box: 26 miles and 385 yards.',
                    ),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 12,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 116,
              height: 82,
              child: CustomPaint(
                painter: _StadiumProgressPainter(progress: progress),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StadiumProgressPainter extends CustomPainter {
  const _StadiumProgressPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final RRect track = RRect.fromRectAndRadius(
      rect.deflate(8),
      Radius.circular(size.height / 2),
    );
    final Paint base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.18);
    canvas.drawRRect(track, base);

    final ui.Path path = ui.Path()..addRRect(track);
    final ui.PathMetric metric = path.computeMetrics().first;
    final ui.Path progressPath = metric.extractPath(
      0,
      metric.length * progress,
    );
    final Paint fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFB84D), Color(0xFF8C63F6), Color(0xFFECFF6B)],
      ).createShader(rect);
    canvas.drawPath(progressPath, fill);

    final Paint inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.28);
    for (int i = 1; i <= 3; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.deflate(8 + i * 8),
          Radius.circular(size.height / 2),
        ),
        inner,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StadiumProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _RunMap extends StatelessWidget {
  const _RunMap({required this.route});

  final List<RoutePoint> route;

  @override
  Widget build(BuildContext context) {
    if (route.length < 2) {
      return Center(
        child: Text(
          context.tr(
            'Маршрут появится после движения',
            'The route will appear after movement',
          ),
        ),
      );
    }
    final List<LatLng> points = route
        .map((RoutePoint p) => LatLng(p.lat, p.lng))
        .toList(growable: false);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: FlutterMap(
        options: MapOptions(
          initialCenter: points.last,
          initialZoom: 15,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.none,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
            userAgentPackageName: 'kazer.app',
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: points,
                color: Colors.blue.shade500,
                strokeWidth: 4,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
