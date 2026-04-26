import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

void main() {
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
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      createdAtIso: json['createdAtIso'] as String,
      plannedDateIso: json['plannedDateIso'] as String? ?? json['createdAtIso'] as String,
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

class AppData {
  const AppData({
    required this.profile,
    required this.totalWorkouts,
    required this.workoutDays,
    required this.runDays,
    required this.runs,
    required this.foodEntries,
    required this.plannedWorkouts,
    required this.rememberedExerciseSets,
    required this.completedWorkouts,
  });

  final UserProfile profile;
  final int totalWorkouts;
  final List<String> workoutDays;
  final List<String> runDays;
  final List<RunEntry> runs;
  final List<FoodEntry> foodEntries;
  final List<PlannedWorkout> plannedWorkouts;
  final Map<String, int> rememberedExerciseSets;
  final List<CompletedWorkout> completedWorkouts;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'profile': profile.toJson(),
      'totalWorkouts': totalWorkouts,
      'workoutDays': workoutDays,
      'runDays': runDays,
      'runs': runs.map((RunEntry e) => e.toJson()).toList(),
      'foodEntries': foodEntries.map((FoodEntry e) => e.toJson()).toList(),
      'plannedWorkouts': plannedWorkouts.map((PlannedWorkout e) => e.toJson()).toList(),
      'rememberedExerciseSets': rememberedExerciseSets,
      'completedWorkouts':
          completedWorkouts.map((CompletedWorkout e) => e.toJson()).toList(),
    };
  }

  factory AppData.fromJson(Map<String, dynamic> json) {
    final List<PlannedWorkout> planned = (json['plannedWorkouts'] as List<dynamic>? ?? <dynamic>[])
        .map((dynamic e) => PlannedWorkout.fromJson(e as Map<String, dynamic>))
        .toList();
    if (planned.isEmpty && json['activeWorkout'] != null) {
      planned.add(
        PlannedWorkout.fromJson(json['activeWorkout'] as Map<String, dynamic>).copyWith(
          plannedDateIso: DateTime.now().toIso8601String(),
        ),
      );
    }
    return AppData(
      profile: UserProfile.fromJson(json['profile'] as Map<String, dynamic>),
      totalWorkouts: json['totalWorkouts'] as int? ?? 0,
      workoutDays: (json['workoutDays'] as List<dynamic>? ??
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
          (json['rememberedExerciseSets'] as Map<String, dynamic>? ?? <String, dynamic>{})
              .map((String key, dynamic value) => MapEntry(key, value as int)),
      completedWorkouts:
          (json['completedWorkouts'] as List<dynamic>? ?? <dynamic>[])
              .map(
                (dynamic e) =>
                    CompletedWorkout.fromJson(e as Map<String, dynamic>),
              )
              .toList(),
    );
  }

  AppData copyWith({
    UserProfile? profile,
    int? totalWorkouts,
    List<String>? workoutDays,
    List<String>? runDays,
    List<RunEntry>? runs,
    List<FoodEntry>? foodEntries,
    List<PlannedWorkout>? plannedWorkouts,
    Map<String, int>? rememberedExerciseSets,
    List<CompletedWorkout>? completedWorkouts,
  }) {
    return AppData(
      profile: profile ?? this.profile,
      totalWorkouts: totalWorkouts ?? this.totalWorkouts,
      workoutDays: workoutDays ?? this.workoutDays,
      runDays: runDays ?? this.runDays,
      runs: runs ?? this.runs,
      foodEntries: foodEntries ?? this.foodEntries,
      plannedWorkouts: plannedWorkouts ?? this.plannedWorkouts,
      rememberedExerciseSets: rememberedExerciseSets ?? this.rememberedExerciseSets,
      completedWorkouts: completedWorkouts ?? this.completedWorkouts,
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
        totalWorkouts: 0,
        workoutDays: <String>[],
        runDays: <String>[],
        runs: <RunEntry>[],
        foodEntries: <FoodEntry>[],
        plannedWorkouts: <PlannedWorkout>[],
        rememberedExerciseSets: <String, int>{},
        completedWorkouts: <CompletedWorkout>[],
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

class KazeRunnerApp extends StatelessWidget {
  const KazeRunnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kaze Runner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
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
  AppData? _appData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final AppData? data = await _storage.loadData();
    if (!mounted) {
      return;
    }
    setState(() {
      _appData = data;
      _loading = false;
    });
  }

  Future<void> _createProfile(UserProfile profile) async {
    final AppData data = AppData(
      profile: profile,
      totalWorkouts: 0,
      workoutDays: <String>[],
      runDays: <String>[],
      runs: <RunEntry>[],
      foodEntries: <FoodEntry>[],
      plannedWorkouts: <PlannedWorkout>[],
      rememberedExerciseSets: <String, int>{},
      completedWorkouts: <CompletedWorkout>[],
    );
    await _storage.saveData(data);
    if (!mounted) {
      return;
    }
    setState(() {
      _appData = data;
    });
  }

  Future<void> _saveAppData(AppData data) async {
    await _storage.saveData(data);
    if (!mounted) {
      return;
    }
    setState(() {
      _appData = data;
    });
  }

  Future<void> _deleteData() async {
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
      return AccountCreationScreen(onSubmit: _createProfile);
    }
    return MainTabsScreen(
      appData: _appData!,
      onSaveData: _saveAppData,
      onDeleteProfile: _deleteData,
    );
  }
}

class AccountCreationScreen extends StatefulWidget {
  const AccountCreationScreen({super.key, required this.onSubmit});

  final ValueChanged<UserProfile> onSubmit;

  @override
  State<AccountCreationScreen> createState() => _AccountCreationScreenState();
}

class _AccountCreationScreenState extends State<AccountCreationScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _heightCtrl = TextEditingController();
  final TextEditingController _weightCtrl = TextEditingController();
  final TextEditingController _ageCtrl = TextEditingController();
  final TextEditingController _workoutsCtrl = TextEditingController(text: '3');

  Gender _selectedGender = Gender.male;
  Goal _selectedGoal = Goal.maintain;
  static final RegExp _decimalRegex = RegExp(r'^\d*([.]\d*)?$');

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _ageCtrl.dispose();
    _workoutsCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    widget.onSubmit(
      UserProfile(
        username: _usernameCtrl.text.trim(),
        heightCm: double.parse(_heightCtrl.text.trim()),
        weightKg: double.parse(_weightCtrl.text.trim()),
        gender: _selectedGender,
        age: int.parse(_ageCtrl.text.trim()),
        goal: _selectedGoal,
        workoutsPerWeek: int.parse(_workoutsCtrl.text.trim()),
      ),
    );
  }

  String? _required(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Введите $fieldName';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Создание аккаунта')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _usernameCtrl,
                decoration: const InputDecoration(labelText: 'Имя пользователя'),
                validator: (String? value) => _required(value, 'имя пользователя'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _heightCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(_decimalRegex),
                ],
                decoration: const InputDecoration(labelText: 'Рост (см)'),
                validator: (String? value) {
                  final String? base = _required(value, 'рост');
                  if (base != null) {
                    return base;
                  }
                  final double? parsed = double.tryParse(value!.trim());
                  return (parsed == null || parsed < 100 || parsed > 250)
                      ? 'Рост должен быть от 100 до 250 см'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _weightCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(_decimalRegex),
                ],
                decoration: const InputDecoration(labelText: 'Вес (кг)'),
                validator: (String? value) {
                  final String? base = _required(value, 'вес');
                  if (base != null) {
                    return base;
                  }
                  final double? parsed = double.tryParse(value!.trim());
                  return (parsed == null || parsed < 30 || parsed > 300)
                      ? 'Вес должен быть от 30 до 300 кг'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Gender>(
                initialValue: _selectedGender,
                decoration: const InputDecoration(labelText: 'Пол'),
                items: Gender.values
                    .map((Gender g) => DropdownMenuItem(value: g, child: Text(g.label)))
                    .toList(),
                onChanged: (Gender? value) {
                  if (value != null) {
                    setState(() => _selectedGender = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ageCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Возраст'),
                validator: (String? value) {
                  final String? base = _required(value, 'возраст');
                  if (base != null) {
                    return base;
                  }
                  final int? parsed = int.tryParse(value!.trim());
                  return (parsed == null || parsed < 10 || parsed > 120)
                      ? 'Возраст должен быть от 10 до 120'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Goal>(
                initialValue: _selectedGoal,
                decoration: const InputDecoration(labelText: 'Цель'),
                items: Goal.values
                    .map((Goal g) => DropdownMenuItem(value: g, child: Text(g.label)))
                    .toList(),
                onChanged: (Goal? value) {
                  if (value != null) {
                    setState(() => _selectedGoal = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _workoutsCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration:
                    const InputDecoration(labelText: 'Тренировок в неделю (1-7)'),
                validator: (String? value) {
                  final String? base = _required(value, 'число тренировок');
                  if (base != null) {
                    return base;
                  }
                  final int? parsed = int.tryParse(value!.trim());
                  return (parsed == null || parsed < 1 || parsed > 7)
                      ? 'Введите число от 1 до 7'
                      : null;
                },
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: _submit, child: const Text('Создать аккаунт')),
              const SizedBox(height: 8),
              const Text(
                'Все данные хранятся только на этом устройстве.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
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

  String _dayKey(DateTime date) {
    final String mm = date.month.toString().padLeft(2, '0');
    final String dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }

  Future<void> _saveProfile(UserProfile profile) async {
    await widget.onSaveData(widget.appData.copyWith(profile: profile));
  }

  Future<void> _saveRun(RunEntry run) async {
    final List<RunEntry> runs = List<RunEntry>.from(widget.appData.runs)..insert(0, run);
    final Set<String> days = widget.appData.runDays.toSet()..add(_dayKey(run.startedAt));
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

  DateTime _normalizeDate(DateTime date) => DateTime(date.year, date.month, date.day);

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _scheduleWorkout(
    List<String> exerciseNames,
    DateTime date, {
    String? editingId,
  }) async {
    final DateTime normalizedDate = _normalizeDate(date);
    final List<PlannedWorkout> planned = List<PlannedWorkout>.from(widget.appData.plannedWorkouts);
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
      exercises: exerciseNames
          .map((String e) {
            final int rememberedSets = widget.appData.rememberedExerciseSets[e] ?? 3;
            return PlannedExercise(name: e, sets: rememberedSets, reps: 10);
          })
          .toList(),
    );
    final Map<String, int> remembered = Map<String, int>.from(widget.appData.rememberedExerciseSets);
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
      final Set<String> workoutDays = widget.appData.workoutDays.toSet()..add(_dayKey(normalizedDate));
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
      final int index = planned.indexWhere((PlannedWorkout p) => p.id == editingId);
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
    final List<PlannedWorkout> planned = List<PlannedWorkout>.from(widget.appData.plannedWorkouts)
      ..removeWhere((PlannedWorkout p) => p.id == id);
    await widget.onSaveData(widget.appData.copyWith(plannedWorkouts: planned));
  }

  Future<void> _updatePlannedWorkout(PlannedWorkout workout) async {
    final List<PlannedWorkout> planned = List<PlannedWorkout>.from(widget.appData.plannedWorkouts);
    final int index = planned.indexWhere((PlannedWorkout p) => p.id == workout.id);
    if (index >= 0) {
      planned[index] = workout;
      await widget.onSaveData(widget.appData.copyWith(plannedWorkouts: planned));
    }
  }

  Future<void> _saveRememberedSets(Map<String, int> values) async {
    await widget.onSaveData(widget.appData.copyWith(rememberedExerciseSets: values));
  }

  Future<void> _completeWorkout(PlannedWorkout planned, WorkoutEmotion emotion) async {
    if (!widget.appData.plannedWorkouts.any((PlannedWorkout p) => p.id == planned.id)) {
      return;
    }
    final DateTime now = DateTime.now();
    final int duration = max(60, now.difference(planned.createdAt).inSeconds);
    final CompletedWorkout completed = CompletedWorkout(
      completedAtIso: now.toIso8601String(),
      durationSeconds: duration,
      emotion: emotion,
      exercises: planned.exercises,
    );
    final List<CompletedWorkout> history =
        List<CompletedWorkout>.from(widget.appData.completedWorkouts)..insert(0, completed);
    final List<PlannedWorkout> remaining =
        List<PlannedWorkout>.from(widget.appData.plannedWorkouts)
          ..removeWhere((PlannedWorkout p) => p.id == planned.id);
    final Set<String> days = widget.appData.workoutDays.toSet()..add(_dayKey(now));
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
    final List<Widget> pages = [
      ActivityScreen(
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
      RunScreen(runs: widget.appData.runs, onRunSaved: _saveRun),
      ProfileScreen(
        appData: widget.appData,
        onProfileUpdated: _saveProfile,
        onDeleteProfile: widget.onDeleteProfile,
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(_titleForIndex(_selectedIndex))),
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center),
            label: 'Активность',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_outlined),
            selectedIcon: Icon(Icons.restaurant),
            label: 'Еда',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_run_outlined),
            selectedIcon: Icon(Icons.directions_run),
            label: 'Бег',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }

  String _titleForIndex(int index) {
    switch (index) {
      case 0:
        return 'Активность';
      case 1:
        return 'Еда';
      case 2:
        return 'Бег';
      case 3:
        return 'Профиль';
      default:
        return 'Kaze Runner';
    }
  }
}

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({
    super.key,
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

  final List<PlannedWorkout> plannedWorkouts;
  final Map<String, int> rememberedExerciseSets;
  final List<CompletedWorkout> completedWorkouts;
  final int totalWorkouts;
  final Future<void> Function(
    List<String> names,
    DateTime date, {
    String? editingId,
  }) onScheduleWorkout;
  final Future<void> Function(PlannedWorkout planned) onUpdatePlannedWorkout;
  final Future<void> Function(String id) onDeletePlannedWorkout;
  final Future<void> Function(Map<String, int> values) onSaveRememberedSets;
  final Future<void> Function(PlannedWorkout planned, WorkoutEmotion emotion) onCompleteWorkout;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  bool _expanded = true;
  final Set<String> _rememberedExercises = <String>{};
  final Map<String, int> _rememberedSets = <String, int>{};

  @override
  void initState() {
    super.initState();
    _rememberedSets.addAll(widget.rememberedExerciseSets);
  }

  DateTime _normalized(DateTime date) => DateTime(date.year, date.month, date.day);

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
              title: const Text('План тренировки'),
              content: SizedBox(
                width: 380,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Дата тренировки'),
                        subtitle: Text(
                          '${selectedDate.day.toString().padLeft(2, '0')}.${selectedDate.month.toString().padLeft(2, '0')}.${selectedDate.year}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_calendar),
                          onPressed: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                              initialDate: selectedDate,
                            );
                            if (picked != null) {
                              setState(() => selectedDate = _normalized(picked));
                            }
                          },
                        ),
                      ),
                      for (final String item in preset)
                        CheckboxListTile(
                          value: selected.contains(item),
                          contentPadding: EdgeInsets.zero,
                          title: Text(item),
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
                          labelText: 'Свое упражнение',
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
                                .map((String e) => Chip(label: Text(e)))
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
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () => Navigator.pop(
                            context,
                            _PlanDialogResult(
                              selected.toList(),
                              selectedDate,
                            ),
                          ),
                  child: const Text('Добавить'),
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
        const SnackBar(content: Text('На эту дату уже есть тренировка')),
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
          title: const Text('Оцените тренировку'),
          content: Wrap(
            spacing: 10,
            children: WorkoutEmotion.values
                .map(
                  (WorkoutEmotion e) => ChoiceChip(
                    selected: false,
                    label: Text('${e.emoji} ${e.label}'),
                    onSelected: (_) => Navigator.pop(context, e),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
    if (emotion != null) {
      await widget.onCompleteWorkout(workout, emotion);
    }
  }

  Future<void> _changeExercise(
    PlannedWorkout workout,
    int index,
    PlannedExercise next,
  ) async {
    final List<PlannedExercise> list = List<PlannedExercise>.from(workout.exercises);
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
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          child: _WorkoutCalendarSheet(
            plannedWorkouts: widget.plannedWorkouts,
            completedWorkouts: widget.completedWorkouts,
            onDateTap: (DateTime date) async {
              final PlannedWorkout? planned = _plannedForDate(date);
              if (planned == null) {
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('На эту дату нет запланированной тренировки')),
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
                          leading: const Icon(Icons.edit_outlined),
                          title: const Text('Редактировать'),
                          onTap: () async {
                            Navigator.of(context).pop();
                            await _openPlanDialog(editing: planned);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.event_repeat_outlined),
                          title: const Text('Перенести дату'),
                          onTap: () async {
                            Navigator.of(context).pop();
                            final DateTime? newDate = await showDatePicker(
                              context: this.context,
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                              initialDate: planned.plannedDate,
                            );
                            if (newDate == null) return;
                            final PlannedWorkout? conflict = _plannedForDate(newDate);
                            if (conflict != null && conflict.id != planned.id) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(content: Text('На эту дату уже есть тренировка')),
                              );
                              return;
                            }
                            await widget.onUpdatePlannedWorkout(
                              planned.copyWith(
                                plannedDateIso: _normalized(newDate).toIso8601String(),
                              ),
                            );
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.delete_outline),
                          title: const Text('Удалить тренировку'),
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
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _openWorkoutCalendar,
        child: const Icon(Icons.calendar_month_outlined),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
        Card(
          child: ListTile(
            title: const Text('Тренировок за все время'),
            subtitle: Text('${widget.totalWorkouts}'),
            trailing: FilledButton.icon(
              onPressed: _openPlanDialog,
              icon: const Icon(Icons.add),
              label: const Text('Добавить'),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (active != null)
          Card(
            color: Colors.teal.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department, color: Colors.teal),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Активная тренировка')),
                      IconButton(
                        onPressed: () => setState(() => _expanded = !_expanded),
                        icon: Icon(
                          _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        ),
                      ),
                    ],
                  ),
                  Text('Начата: ${_fmtDate(active.createdAt)}'),
                  if (_expanded) ...[
                    const SizedBox(height: 8),
                    for (int i = 0; i < active.exercises.length; i++)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(active.exercises[i].name),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: '${active.exercises[i].sets}',
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Подходы',
                                      ),
                                      onChanged: (String value) {
                                        final int? parsed = int.tryParse(value);
                                        if (parsed != null && parsed > 0) {
                                          _changeExercise(
                                            active,
                                            i,
                                            active.exercises[i].copyWith(sets: parsed),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: '${active.exercises[i].reps}',
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Повторения',
                                      ),
                                      onChanged: (String value) {
                                        final int? parsed = int.tryParse(value);
                                        if (parsed != null && parsed > 0) {
                                          _changeExercise(
                                            active,
                                            i,
                                            active.exercises[i].copyWith(reps: parsed),
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
                        label: const Text('Завершить тренировку'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        if (active != null) const SizedBox(height: 12),
        Text('История тренировок', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (widget.completedWorkouts.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text('Пока нет завершенных тренировок'),
            ),
          ),
        for (final CompletedWorkout w in widget.completedWorkouts)
          Card(
            child: ExpansionTile(
              title: Text('${w.emotion.emoji} ${w.emotion.label}'),
              subtitle: Text(
                '${_fmtDate(w.completedAt)} • ${_fmtDuration(w.durationSeconds)} • ${w.exercises.length} упражнений',
              ),
              children: [
                for (final PlannedExercise ex in w.exercises)
                  ListTile(
                    dense: true,
                    title: Text(ex.name),
                    subtitle: Text('Подходы: ${ex.sets}, Повторения: ${ex.reps}'),
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

  DateTime _normalized(DateTime date) => DateTime(date.year, date.month, date.day);

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _displayedMonth = DateTime(now.year, now.month, 1);
  }

  String _monthLabel(DateTime date) {
    const List<String> monthNames = <String>[
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
    return '${monthNames[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final DateTime monthStart = DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    final int daysInMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;
    final int leading = monthStart.weekday - 1;
    final int totalCells = ((leading + daysInMonth + 6) ~/ 7) * 7;

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
                      'Календарь тренировок',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Предыдущий месяц',
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
                  Text(_monthLabel(_displayedMonth)),
                  IconButton(
                    tooltip: 'Следующий месяц',
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
                  _LegendTag(color: Colors.green.shade500, text: 'Прошедшая'),
                  _LegendTag(color: Colors.blue.shade500, text: 'Будущая'),
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
                      (PlannedWorkout p) => _sameDay(_normalized(p.plannedDate), normalized),
                    );
                    final bool hasCompleted = widget.completedWorkouts.any(
                      (CompletedWorkout c) => _sameDay(_normalized(c.completedAt), normalized),
                    );
                    Color? marker;
                    if (hasCompleted) {
                      marker = Colors.green.shade500;
                    } else if (hasPlanned && normalized.isAfter(_normalized(now))) {
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
                              fontWeight: marker != null ? FontWeight.w700 : FontWeight.w400,
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
  const EmptyPlaceholderScreen({super.key, required this.title, required this.subtitle});

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
  static final RegExp _decimalRegex = RegExp(r'^\d*([.]\d*)?$');
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
  static const Map<String, (double kcal, double protein, double fat, double carbs)> _presetMeals =
      <String, (double, double, double, double)>{
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
  bool get _visionSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

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
      return value.expand((dynamic item) => _flattenToDoubleList(item)).toList();
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
    final List<double> expVals =
        logits.map((double v) => exp(v - maxLogit)).toList(growable: false);
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
      final dynamic foodOutput = _newTensorBuffer(_foodModel!.getOutputTensor(0).shape);
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
    final TextEditingController nameCtrl = TextEditingController(text: current.foodLabel);
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
                    decoration: const InputDecoration(labelText: 'Название блюда'),
                  ),
                  TextField(
                    controller: kcalCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(_decimalRegex)],
                    decoration: const InputDecoration(labelText: 'Калории'),
                  ),
                  TextField(
                    controller: proteinCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(_decimalRegex)],
                    decoration: const InputDecoration(labelText: 'Белки (г)'),
                  ),
                  TextField(
                    controller: fatCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(_decimalRegex)],
                    decoration: const InputDecoration(labelText: 'Жиры (г)'),
                  ),
                  TextField(
                    controller: carbsCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(_decimalRegex)],
                    decoration: const InputDecoration(labelText: 'Углеводы (г)'),
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
                    calories: double.tryParse(kcalCtrl.text.trim()) ?? current.calories,
                    protein: double.tryParse(proteinCtrl.text.trim()) ?? current.protein,
                    fat: double.tryParse(fatCtrl.text.trim()) ?? current.fat,
                    carbs: double.tryParse(carbsCtrl.text.trim()) ?? current.carbs,
                  ),
                );
              },
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );
    nameCtrl.dispose();
    kcalCtrl.dispose();
    proteinCtrl.dispose();
    fatCtrl.dispose();
    carbsCtrl.dispose();
    if (edited == null || !mounted) return;
    setState(() => _visionResult = edited);
  }

  Future<void> _applyVisionResultAsFoodEntry() async {
    final _FoodVisionResult? result = _visionResult;
    if (result == null) return;
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
    _showMessage('Распознанное блюдо добавлено в дневник');
  }
  DateTime _today() {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _weekStart(DateTime date) => date.subtract(Duration(days: date.weekday - 1));

  String _dayKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _save(List<FoodEntry> entries) async {
    entries.sort((FoodEntry a, FoodEntry b) => b.date.compareTo(a.date));
    await widget.onChanged(entries);
  }

  Future<void> _openFoodForm({FoodEntry? edit}) async {
    DateTime selectedDate = edit?.date ?? _today();
    String? selectedPreset;
    final TextEditingController nameCtrl = TextEditingController(text: edit?.name ?? '');
    final TextEditingController kcalCtrl = TextEditingController(text: '${edit?.calories ?? 0}');
    final TextEditingController proteinCtrl =
        TextEditingController(text: '${edit?.protein ?? 0}');
    final TextEditingController fatCtrl = TextEditingController(text: '${edit?.fat ?? 0}');
    final TextEditingController carbsCtrl =
        TextEditingController(text: '${edit?.carbs ?? 0}');
    final TextEditingController waterCtrl = TextEditingController(text: '${edit?.waterMl ?? 0}');

    final FoodEntry? result = await showDialog<FoodEntry>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setStateDialog) {
            return AlertDialog(
              title: Text(edit == null ? 'Добавить прием пищи' : 'Редактировать запись'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 380,
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Дата'),
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
                        decoration: const InputDecoration(labelText: 'Блюдо/напиток'),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: selectedPreset,
                        decoration: const InputDecoration(labelText: 'Выбрать блюдо из списка'),
                        items: _presetMeals.keys
                            .map(
                              (String meal) =>
                                  DropdownMenuItem<String>(value: meal, child: Text(meal)),
                            )
                            .toList(),
                        onChanged: (String? value) {
                          if (value == null) return;
                          final (double kcal, double protein, double fat, double carbs) =
                              _presetMeals[value]!;
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
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(_decimalRegex),
                        ],
                        decoration: const InputDecoration(labelText: 'Калории'),
                      ),
                      TextField(
                        controller: proteinCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(_decimalRegex),
                        ],
                        decoration: const InputDecoration(labelText: 'Белки (г)'),
                      ),
                      TextField(
                        controller: fatCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(_decimalRegex),
                        ],
                        decoration: const InputDecoration(labelText: 'Жиры (г)'),
                      ),
                      TextField(
                        controller: carbsCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(_decimalRegex),
                        ],
                        decoration: const InputDecoration(labelText: 'Углеводы (г)'),
                      ),
                      TextField(
                        controller: waterCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(labelText: 'Жидкость (мл)'),
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
                    final int waterMl = (int.tryParse(waterCtrl.text.trim()) ?? 0)
                        .clamp(0, _maxWaterMlPerDay);
                    final FoodEntry next = FoodEntry(
                      id: edit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                      dateIso: DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                      ).toIso8601String(),
                      name: nameCtrl.text.trim().isEmpty
                          ? 'Без названия'
                          : nameCtrl.text.trim(),
                      calories: double.tryParse(kcalCtrl.text.trim()) ?? 0,
                      protein: double.tryParse(proteinCtrl.text.trim()) ?? 0,
                      fat: double.tryParse(fatCtrl.text.trim()) ?? 0,
                      carbs: double.tryParse(carbsCtrl.text.trim()) ?? 0,
                      waterMl: waterMl,
                    );
                    Navigator.pop(context, next);
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );

    nameCtrl.dispose();
    kcalCtrl.dispose();
    proteinCtrl.dispose();
    fatCtrl.dispose();
    carbsCtrl.dispose();
    waterCtrl.dispose();

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final DateTime today = _today();
    final DateTime weekStart = _weekStart(today);
    final DateTime weekEnd = weekStart.add(const Duration(days: 6));

    final List<FoodEntry> todayEntries =
        widget.entries.where((FoodEntry e) => _sameDay(e.date, today)).toList();
    final List<FoodEntry> weekEntries = widget.entries
        .where((FoodEntry e) => !e.date.isBefore(weekStart) && !e.date.isAfter(weekEnd))
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

    return Scaffold(
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'food_camera_fab',
            onPressed: _inferenceLoading || !_visionSupported ? null : _captureAndInfer,
            icon: _inferenceLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.photo_camera_outlined),
            label: const Text('Камера'),
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
          if (_modelsLoading)
            const Card(
              child: ListTile(
                leading: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                title: Text('Загрузка ML-моделей...'),
              ),
            ),
          if (_visionError != null)
            Card(
              color: Colors.red.withValues(alpha: 0.08),
              child: ListTile(
                leading: const Icon(Icons.error_outline, color: Colors.red),
                title: const Text('Ошибка распознавания'),
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
                        const Expanded(child: Text('Результат AI')),
                        TextButton.icon(
                          onPressed: _editVisionResult,
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Редактировать'),
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
                    Text(_visionResult!.foodLabel, style: Theme.of(context).textTheme.titleMedium),
                    Text('Уверенность: ${(_visionResult!.confidence * 100).toStringAsFixed(1)}%'),
                    const SizedBox(height: 4),
                    Text(
                      'Калории ${_visionResult!.calories.toStringAsFixed(0)} • '
                      'Белки ${_visionResult!.protein.toStringAsFixed(1)} • '
                      'Жиры ${_visionResult!.fat.toStringAsFixed(1)} • '
                      'Углеводы ${_visionResult!.carbs.toStringAsFixed(1)}',
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _applyVisionResultAsFoodEntry,
                        icon: const Icon(Icons.add_task_outlined),
                        label: const Text('Добавить в дневник'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: [Text('Сегодня', style: Theme.of(context).textTheme.titleLarge)],
          ),
          Card(
            child: ListTile(
              title: const Text('Сегодня'),
              subtitle: Text(
                'Калории ${sumCalories(todayEntries).toStringAsFixed(0)} • Белки ${sumProtein(todayEntries).toStringAsFixed(1)} • Жиры ${sumFat(todayEntries).toStringAsFixed(1)} • Углеводы ${sumCarbs(todayEntries).toStringAsFixed(1)} • Вода ${sumWater(todayEntries)} мл',
              ),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Неделя'),
              subtitle: Text(
                'Калории ${sumCalories(weekEntries).toStringAsFixed(0)} • Белки ${sumProtein(weekEntries).toStringAsFixed(1)} • Жиры ${sumFat(weekEntries).toStringAsFixed(1)} • Углеводы ${sumCarbs(weekEntries).toStringAsFixed(1)} • Вода ${sumWater(weekEntries)} мл',
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
            const Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('Пока нет записей по еде и напиткам'),
              ),
            ),
          for (final FoodEntry e in widget.entries)
            Card(
              child: ListTile(
                title: Text(e.name),
                subtitle: Text(
                  '${e.date.day.toString().padLeft(2, '0')}.${e.date.month.toString().padLeft(2, '0')}.${e.date.year} • ${e.calories.toStringAsFixed(0)} ккал • Вода ${e.waterMl} мл',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (String action) async {
                    if (action == 'edit') {
                      await _openFoodForm(edit: e);
                    } else {
                      final List<FoodEntry> list = List<FoodEntry>.from(widget.entries)
                        ..removeWhere((FoodEntry item) => item.id == e.id);
                      await _save(list);
                    }
                  },
                  itemBuilder: (BuildContext context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Редактировать')),
                    PopupMenuItem(value: 'delete', child: Text('Удалить')),
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

class _WaterBottlesWidget extends StatelessWidget {
  const _WaterBottlesWidget({
    required this.consumedMl,
    required this.maxMl,
  });

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
                final double fill = ((consumedMl - start) / bottleMl).clamp(0.0, 1.0);
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

  DateTime _weekStart(DateTime date) => date.subtract(Duration(days: date.weekday - 1));

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final DateTime start = _weekStart(now);
    final List<double> water = List<double>.filled(7, 0);
    final List<double> kcal = List<double>.filled(7, 0);
    for (final FoodEntry e in entries) {
      final DateTime d = DateTime(e.date.year, e.date.month, e.date.day);
      if (d.isBefore(start) || d.isAfter(start.add(const Duration(days: 6)))) continue;
      final int idx = d.difference(start).inDays;
      water[idx] += e.waterMl.toDouble();
      kcal[idx] += e.calories;
    }
    return Column(
      children: [
        _SimpleWeekBarChart(title: 'Вода за неделю (мл)', values: water, color: Colors.blue),
        const SizedBox(height: 8),
        _SimpleWeekBarChart(title: 'Калории за неделю', values: kcal, color: Colors.deepOrange),
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
    required this.onDeleteProfile,
  });

  final AppData appData;
  final Future<void> Function(UserProfile profile) onProfileUpdated;
  final Future<void> Function() onDeleteProfile;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _updatingAvatar = false;

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
    final String ext = sourcePath.contains('.') ? sourcePath.split('.').last : 'jpg';
    final String targetPath = '${avatarsDir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
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
      final UserProfile updated = widget.appData.profile.copyWith(avatarPath: savedPath);
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
        title: 'Первые шаги',
        description: 'Сделать 1 физическую тренировку',
        done: workoutCount >= 1,
      ),
      _AchievementItem(
        title: 'Разогнался',
        description: 'Сделать 10 физических тренировок',
        done: workoutCount >= 10,
      ),
      _AchievementItem(
        title: 'Машина',
        description: 'Сделать 100 физических тренировок',
        done: workoutCount >= 100,
      ),
    ];
  }

  List<_AchievementItem> _buildRunAchievements() {
    final int runs = widget.appData.runs.length;
    return <_AchievementItem>[
      _AchievementItem(
        title: 'Беговой старт',
        description: 'Завершить 1 пробежку',
        done: runs >= 1,
      ),
      _AchievementItem(
        title: 'Ритм',
        description: 'Завершить 10 пробежек',
        done: runs >= 10,
      ),
      _AchievementItem(
        title: 'Дистанция',
        description: 'Завершить 50 пробежек',
        done: runs >= 50,
      ),
    ];
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final UserProfile profile = widget.appData.profile;
    final List<_AchievementItem> workoutAchievements = _buildWorkoutAchievements();
    final List<_AchievementItem> runAchievements = _buildRunAchievements();
    final String? avatarPath = profile.avatarPath;
    final bool avatarExists = avatarPath != null && File(avatarPath).existsSync();
    final ImageProvider<Object>? avatarImage =
        avatarExists ? FileImage(File(avatarPath)) : null;
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
                    Text(profile.username, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text('Цель: ${profile.goal.label}'),
                    Text('Тренировок: ${widget.appData.totalWorkouts}'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _ProfileItem(label: 'Рост', value: '${profile.heightCm} см'),
        _ProfileItem(label: 'Вес', value: '${profile.weightKg} кг'),
        _ProfileItem(label: 'Пол', value: profile.gender.label),
        _ProfileItem(label: 'Возраст', value: '${profile.age}'),
        _ProfileItem(label: 'Тренировок в неделю', value: '${profile.workoutsPerWeek}'),
        const SizedBox(height: 16),
        Text('Ачивки: тренировки', style: Theme.of(context).textTheme.titleMedium),
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
              trailing: Text(item.done ? 'Получено' : 'В процессе'),
            ),
          ),
        const SizedBox(height: 16),
        Text('Ачивки: бег', style: Theme.of(context).textTheme.titleMedium),
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
              trailing: Text(item.done ? 'Получено' : 'В процессе'),
            ),
          ),
        const SizedBox(height: 16),
        Text('Календарь активности', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _LegendTag(color: Colors.green.shade500, text: 'Тренировка'),
            _LegendTag(color: Colors.blue.shade500, text: 'Пробежка'),
            const _LegendMixedTag(),
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
          label: const Text('Удалить аккаунт с устройства'),
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
    return Card(child: ListTile(title: Text(label), subtitle: Text(value)));
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
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(text),
      ],
    );
  }
}

class _LegendMixedTag extends StatelessWidget {
  const _LegendMixedTag();

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
        const Text('И тренировка, и бег'),
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
  const RunScreen({super.key, required this.runs, required this.onRunSaved});

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
    setState(() => _requesting = true);
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMessage('Включите геолокацию на устройстве');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage('Разрешите доступ к геолокации');
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
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 5,
        ),
      ).listen((Position p) {
        final RoutePoint next = RoutePoint(p.latitude, p.longitude);
        if (_points.isNotEmpty) {
          final RoutePoint prev = _points.last;
          _distanceKm += Geolocator.distanceBetween(
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
    _showMessage('Пробежка сохранена');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Таймер: ${_fmtDuration(_seconds)}'),
                Text('Дистанция: ${_distanceKm.toStringAsFixed(2)} км'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _running || _requesting ? null : _startRun,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Начать пробежку'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _running ? _stopRun : null,
                      icon: const Icon(Icons.stop),
                      label: const Text('Завершить'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('История пробежек', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (widget.runs.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Пока нет сохраненных пробежек'),
            ),
          ),
        for (final RunEntry run in widget.runs)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Дата: ${_fmtDate(run.startedAt)}'),
                  Text('Время: ${_fmtDuration(run.durationSeconds)}'),
                  Text('Километраж: ${run.distanceKm.toStringAsFixed(2)} км'),
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

class _RunMap extends StatelessWidget {
  const _RunMap({required this.route});

  final List<RoutePoint> route;

  @override
  Widget build(BuildContext context) {
    if (route.length < 2) {
      return const Center(child: Text('Маршрут появится после движения'));
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
          interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
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
