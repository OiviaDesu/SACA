part of 'saca_models.dart';

class Symptom {
  const Symptom({required this.id, required this.label});

  final String id;
  final String label;
}

class BodyArea {
  const BodyArea({required this.id, required this.label, required this.view});

  final String id;
  final String label;
  final BodyView view;
}
