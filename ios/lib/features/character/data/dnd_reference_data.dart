import '../models/dnd_data.dart';

/// Статические данные D&D 5e SRD
abstract final class DndReferenceData {
  /// Все классы D&D 5e (базовые 12 классов)
  static const List<DndClass> classes = [
    DndClass(
      id: 'barbarian',
      name: 'Barbarian',
      nameRu: 'Варвар',
      hitDie: 'd12',
      primaryAbilities: ['strength'],
      savingThrows: ['strength', 'constitution'],
      description: 'A fierce warrior who can enter a battle rage',
      descriptionRu: 'Яростный воин, способный впадать в боевую ярость',
      iconEmoji: '🪓',
    ),
    DndClass(
      id: 'bard',
      name: 'Bard',
      nameRu: 'Бард',
      hitDie: 'd8',
      primaryAbilities: ['charisma'],
      savingThrows: ['dexterity', 'charisma'],
      description: 'An inspiring magician whose music creates magic',
      descriptionRu: 'Вдохновляющий маг, чья музыка творит волшебство',
      iconEmoji: '🎸',
    ),
    DndClass(
      id: 'cleric',
      name: 'Cleric',
      nameRu: 'Жрец',
      hitDie: 'd8',
      primaryAbilities: ['wisdom'],
      savingThrows: ['wisdom', 'charisma'],
      description: 'A priestly champion who wields divine magic',
      descriptionRu: 'Жреческий воитель, владеющий божественной магией',
      iconEmoji: '⛪',
    ),
    DndClass(
      id: 'druid',
      name: 'Druid',
      nameRu: 'Друид',
      hitDie: 'd8',
      primaryAbilities: ['wisdom'],
      savingThrows: ['intelligence', 'wisdom'],
      description: 'A priest of the Old Faith, wielding the powers of nature',
      descriptionRu: 'Жрец Старой Веры, повелевающий силами природы',
      iconEmoji: '🌿',
    ),
    DndClass(
      id: 'fighter',
      name: 'Fighter',
      nameRu: 'Воин',
      hitDie: 'd10',
      primaryAbilities: ['strength', 'dexterity'],
      savingThrows: ['strength', 'constitution'],
      description: 'A master of martial combat, skilled with weapons and armor',
      descriptionRu: 'Мастер боевых искусств, искусный в обращении с оружием и доспехами',
      iconEmoji: '⚔️',
    ),
    DndClass(
      id: 'monk',
      name: 'Monk',
      nameRu: 'Монах',
      hitDie: 'd8',
      primaryAbilities: ['dexterity', 'wisdom'],
      savingThrows: ['strength', 'dexterity'],
      description: 'A master of martial arts, harnessing the power of ki',
      descriptionRu: 'Мастер боевых искусств, использующий силу ки',
      iconEmoji: '👊',
    ),
    DndClass(
      id: 'paladin',
      name: 'Paladin',
      nameRu: 'Паладин',
      hitDie: 'd10',
      primaryAbilities: ['strength', 'charisma'],
      savingThrows: ['wisdom', 'charisma'],
      description: 'A holy warrior bound to a sacred oath',
      descriptionRu: 'Святой воитель, связанный священной клятвой',
      iconEmoji: '🛡️',
    ),
    DndClass(
      id: 'ranger',
      name: 'Ranger',
      nameRu: 'Следопыт',
      hitDie: 'd10',
      primaryAbilities: ['dexterity', 'wisdom'],
      savingThrows: ['strength', 'dexterity'],
      description: 'A warrior who combats threats on the edges of civilization',
      descriptionRu: 'Воин, сражающийся с угрозами на границах цивилизации',
      iconEmoji: '🏹',
    ),
    DndClass(
      id: 'rogue',
      name: 'Rogue',
      nameRu: 'Плут',
      hitDie: 'd8',
      primaryAbilities: ['dexterity'],
      savingThrows: ['dexterity', 'intelligence'],
      description: 'A scoundrel who uses stealth and trickery',
      descriptionRu: 'Пройдоха, использующий скрытность и хитрость',
      iconEmoji: '🗡️',
    ),
    DndClass(
      id: 'sorcerer',
      name: 'Sorcerer',
      nameRu: 'Чародей',
      hitDie: 'd6',
      primaryAbilities: ['charisma'],
      savingThrows: ['constitution', 'charisma'],
      description: 'A spellcaster who draws on inherent magic',
      descriptionRu: 'Заклинатель, черпающий силу из врождённой магии',
      iconEmoji: '✨',
    ),
    DndClass(
      id: 'warlock',
      name: 'Warlock',
      nameRu: 'Колдун',
      hitDie: 'd8',
      primaryAbilities: ['charisma'],
      savingThrows: ['wisdom', 'charisma'],
      description: 'A wielder of magic derived from a bargain with an extraplanar entity',
      descriptionRu: 'Маг, получивший силу от сделки с потусторонней сущностью',
      iconEmoji: '🔮',
    ),
    DndClass(
      id: 'wizard',
      name: 'Wizard',
      nameRu: 'Волшебник',
      hitDie: 'd6',
      primaryAbilities: ['intelligence'],
      savingThrows: ['intelligence', 'wisdom'],
      description: 'A scholarly magic-user capable of manipulating arcane forces',
      descriptionRu: 'Учёный маг, способный управлять тайными силами',
      iconEmoji: '📖',
    ),
  ];

  /// Все расы D&D 5e (базовые расы из PHB)
  static const List<DndRace> races = [
    DndRace(
      id: 'human',
      name: 'Human',
      nameRu: 'Человек',
      abilityBonuses: {
        'strength': 1,
        'dexterity': 1,
        'constitution': 1,
        'intelligence': 1,
        'wisdom': 1,
        'charisma': 1,
      },
      speed: 30,
      description: 'Versatile and ambitious, humans are the most adaptable race',
      descriptionRu: 'Разносторонние и амбициозные, люди — самая адаптивная раса',
      iconEmoji: '👤',
    ),
    DndRace(
      id: 'elf',
      name: 'Elf',
      nameRu: 'Эльф',
      abilityBonuses: {'dexterity': 2},
      speed: 30,
      description: 'Graceful and long-lived, elves are magical people of otherworldly grace',
      descriptionRu: 'Грациозные и долгоживущие, эльфы — магический народ неземной красоты',
      iconEmoji: '🧝',
    ),
    DndRace(
      id: 'dwarf',
      name: 'Dwarf',
      nameRu: 'Дварф',
      abilityBonuses: {'constitution': 2},
      speed: 25,
      description: 'Bold and hardy, dwarves are known for their skill in warfare and crafting',
      descriptionRu: 'Смелые и выносливые, дварфы известны мастерством в войне и ремесле',
      iconEmoji: '🧔',
    ),
    DndRace(
      id: 'halfling',
      name: 'Halfling',
      nameRu: 'Полурослик',
      abilityBonuses: {'dexterity': 2},
      speed: 25,
      description: 'Small but nimble, halflings are known for their luck and bravery',
      descriptionRu: 'Маленькие, но ловкие, полурослики известны удачливостью и храбростью',
      iconEmoji: '🦶',
    ),
    DndRace(
      id: 'dragonborn',
      name: 'Dragonborn',
      nameRu: 'Драконорождённый',
      abilityBonuses: {'strength': 2, 'charisma': 1},
      speed: 30,
      description: 'Proud dragon-kin, dragonborn look like humanoid dragons',
      descriptionRu: 'Гордые потомки драконов, похожие на гуманоидных драконов',
      iconEmoji: '🐉',
    ),
    DndRace(
      id: 'gnome',
      name: 'Gnome',
      nameRu: 'Гном',
      abilityBonuses: {'intelligence': 2},
      speed: 25,
      description: 'Curious and inventive, gnomes are known for their ingenuity',
      descriptionRu: 'Любопытные и изобретательные, гномы известны своей находчивостью',
      iconEmoji: '🔧',
    ),
    DndRace(
      id: 'half-elf',
      name: 'Half-Elf',
      nameRu: 'Полуэльф',
      abilityBonuses: {'charisma': 2},
      speed: 30,
      description: 'Walking in two worlds, half-elves combine the best of both races',
      descriptionRu: 'Живущие в двух мирах, полуэльфы сочетают лучшее от обеих рас',
      iconEmoji: '🧝‍♂️',
    ),
    DndRace(
      id: 'half-orc',
      name: 'Half-Orc',
      nameRu: 'Полуорк',
      abilityBonuses: {'strength': 2, 'constitution': 1},
      speed: 30,
      description: 'Fierce and enduring, half-orcs are scarred by two legacies',
      descriptionRu: 'Свирепые и выносливые, полуорки отмечены двумя наследиями',
      iconEmoji: '👹',
    ),
    DndRace(
      id: 'tiefling',
      name: 'Tiefling',
      nameRu: 'Тифлинг',
      abilityBonuses: {'intelligence': 1, 'charisma': 2},
      speed: 30,
      description: 'Bearing the mark of fiendish blood, tieflings are often mistrusted',
      descriptionRu: 'Несущие метку демонической крови, тифлинги часто вызывают недоверие',
      iconEmoji: '😈',
    ),
  ];

  /// Найти класс по ID
  static DndClass? findClassById(String id) {
    try {
      return classes.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Найти расу по ID
  static DndRace? findRaceById(String id) {
    try {
      return races.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Получить допустимые значения характеристик (стандартный набор)
  static const List<int> standardArray = [15, 14, 13, 12, 10, 8];

  /// Минимальное значение характеристики
  static const int minAbilityScore = 1;

  /// Максимальное значение характеристики (без магических бонусов)
  static const int maxAbilityScore = 20;

  /// Минимальная сумма характеристик (для валидации)
  static const int minTotalAbilityScore = 60;

  /// Максимальная сумма характеристик (для валидации)
  static const int maxTotalAbilityScore = 90;
}
