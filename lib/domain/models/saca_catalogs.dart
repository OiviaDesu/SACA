import 'saca_models.dart';

class SacaCatalogs {
  const SacaCatalogs._();

  static const symptoms = <Symptom>[
    Symptom(id: 'headache', label: 'Headache'),
    Symptom(id: 'fever', label: 'Fever'),
    Symptom(id: 'stomachache', label: 'Stomachache'),
    Symptom(id: 'sore_throat', label: 'Sore throat'),
    Symptom(id: 'chest_pain', label: 'Chest pain'),
    Symptom(id: 'breathing_trouble', label: 'Breathing trouble'),
    Symptom(id: 'vomiting', label: 'Vomiting'),
    Symptom(id: 'bloating', label: 'Bloating'),
  ];

  static const relatedSymptoms = <Symptom>[
    Symptom(id: 'none', label: 'None'),
    Symptom(id: 'sore_throat', label: 'Sore throat'),
    Symptom(id: 'headache', label: 'Headache'),
    Symptom(id: 'cough', label: 'Cough'),
    Symptom(id: 'nausea_vomiting', label: 'Nausea or vomiting'),
    Symptom(id: 'rash', label: 'Rash'),
    Symptom(id: 'chest_pain', label: 'Chest pain'),
    Symptom(id: 'breathing_trouble', label: 'Breathing trouble'),
  ];

  static const bodyAreas = <BodyArea>[
    BodyArea(id: 'head', label: 'Head', view: BodyView.front),
    BodyArea(id: 'eyes', label: 'Eyes', view: BodyView.front),
    BodyArea(id: 'throat', label: 'Throat', view: BodyView.front),
    BodyArea(id: 'heart', label: 'Heart', view: BodyView.front),
    BodyArea(id: 'chest', label: 'Chest', view: BodyView.front),
    BodyArea(id: 'stomach', label: 'Stomach', view: BodyView.front),
    BodyArea(id: 'hand', label: 'Hand', view: BodyView.front),
    BodyArea(id: 'leg', label: 'Leg', view: BodyView.front),
    BodyArea(id: 'knees', label: 'Knees', view: BodyView.front),
    BodyArea(id: 'toes', label: 'Toes', view: BodyView.front),
    BodyArea(id: 'ears', label: 'Ears', view: BodyView.back),
    BodyArea(id: 'neck', label: 'Neck', view: BodyView.back),
    BodyArea(id: 'shoulder', label: 'Shoulder', view: BodyView.back),
    BodyArea(id: 'back', label: 'Back', view: BodyView.back),
    BodyArea(id: 'arm', label: 'Arm', view: BodyView.back),
    BodyArea(id: 'elbow', label: 'Elbow', view: BodyView.back),
    BodyArea(id: 'lower_back', label: 'Lower Back', view: BodyView.back),
    BodyArea(id: 'finger', label: 'Finger', view: BodyView.back),
    BodyArea(id: 'lower_leg', label: 'Lower Leg', view: BodyView.back),
    BodyArea(id: 'ankle', label: 'Ankle', view: BodyView.back),
  ];
}
