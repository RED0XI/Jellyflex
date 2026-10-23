import 'package:flutter/material.dart';

/// Wo die Navigation sitzt.
enum NavStyle {
  /// Schwebende Leiste oben (Kino-Stil).
  top,

  /// Große Reiter in der Mitte oben – gut vom Sofa und mit Controller.
  tabs,

  /// Feste Seitenleiste links mit allen Bibliotheken.
  sidebar,

  /// Nur das Nötigste: Name, Suche, Profil.
  minimal,
}

/// Kopfbereich der Startseite.
enum HeroStyle {
  /// Großes Banner über die ganze Breite.
  banner,

  /// Zweigeteilt wie eine Zeitschrift: Text links, Bild rechts.
  split,

  /// Kein Banner – die Reihen beginnen direkt.
  none,
}

/// Wie eine Karte zeigt, dass sie gewählt ist (Maus oder Fokus).
enum FocusStyle {
  /// Vergrößern mit weißem Rand.
  zoom,

  /// Leuchtender Rahmen in der Akzentfarbe, etwas größer.
  glow,

  /// Rahmen in der Akzentfarbe, ohne Bewegung.
  outline,

  /// Leicht anheben mit weichem Schatten.
  lift,
}

/// Ein Layout: nicht nur Farben, sondern Aufbau, Formen, Schrift und Abstände.
/// Die Farben (Themes) bleiben davon unabhängig wählbar.
@immutable
class AppLayout {
  const AppLayout({
    required this.id,
    required this.name,
    required this.nameDe,
    required this.description,
    required this.descriptionDe,
    required this.nav,
    required this.hero,
    this.heroHeight = 0.8,
    this.cardScale = 1,
    this.radius = 12,
    this.cardTitles = true,
    this.focus = FocusStyle.zoom,
    this.bodyFont,
    this.headingFont,
    this.headingSize = 21,
    this.headingWeight = FontWeight.w700,
    this.uppercaseHeadings = false,
    this.headingSpacing = -0.2,
    this.rowGap = 26,
    this.cardGap = 18,
    this.retro = false,
  });

  final String id;
  final String name;
  final String nameDe;
  final String description;
  final String descriptionDe;
  final NavStyle nav;
  final HeroStyle hero;

  /// Höhe des Banners als Anteil der Fensterhöhe.
  final double heroHeight;

  /// Kartengröße relativ zum Standard (1 = 168 px breite Poster).
  final double cardScale;

  /// Eckenradius von Karten und Kacheln.
  final double radius;

  /// Titel unter den Karten (sonst erscheint er beim Auswählen im Bild).
  final bool cardTitles;
  final FocusStyle focus;

  /// Schrift für alles (`null` = Windows-Standard). Nur Windows-Schriften –
  /// nichts wird geladen.
  final String? bodyFont;

  /// Schrift für Überschriften (`null` = wie [bodyFont]).
  final String? headingFont;
  final double headingSize;
  final FontWeight headingWeight;
  final bool uppercaseHeadings;
  final double headingSpacing;

  /// Abstand zwischen den Reihen und zwischen den Karten.
  final double rowGap;
  final double cardGap;

  /// Röhrenfernseher-Look: Bildzeilen, leichtes Farbsäumen.
  final bool retro;

  /// Stil für Reihen-Überschriften.
  TextStyle headingStyle([Color? color]) => TextStyle(
    fontFamily: headingFont ?? bodyFont,
    fontSize: headingSize,
    fontWeight: headingWeight,
    letterSpacing: headingSpacing,
    color: color,
    shadows: retro ? retroShadows : null,
  );

  String heading(String text) => uppercaseHeadings ? text.toUpperCase() : text;
}

/// Leichtes Rot/Cyan-Säumen wie bei einer alten Videokassette.
const retroShadows = [
  Shadow(offset: Offset(1.5, 0), color: Color(0x66FF2A6D)),
  Shadow(offset: Offset(-1.5, 0), color: Color(0x6605D9E8)),
];

const appLayouts = [
  AppLayout(
    id: 'cinema',
    name: 'Cinema',
    nameDe: 'Kino',
    description: 'Big banner, floating bar, posters that zoom.',
    descriptionDe: 'Großes Banner, schwebende Leiste, Poster zoomen heran.',
    nav: NavStyle.top,
    hero: HeroStyle.banner,
  ),
  AppLayout(
    id: 'couch',
    name: 'Couch',
    nameDe: 'Sofa',
    description: 'Large tiles and tabs for the TV and controller.',
    descriptionDe: 'Große Kacheln und Reiter für Fernseher und Controller.',
    nav: NavStyle.tabs,
    hero: HeroStyle.banner,
    heroHeight: 0.62,
    cardScale: 1.3,
    radius: 18,
    cardTitles: false,
    focus: FocusStyle.glow,
    bodyFont: 'Bahnschrift',
    headingSize: 27,
    headingWeight: FontWeight.w600,
    headingSpacing: 0.2,
    rowGap: 40,
    cardGap: 26,
  ),
  AppLayout(
    id: 'library',
    name: 'Library',
    nameDe: 'Bibliothek',
    description: 'Sidebar with every library, compact rows – lots at a glance.',
    descriptionDe: 'Seitenleiste mit allen Bibliotheken, kompakte Reihen – viel auf einen Blick.',
    nav: NavStyle.sidebar,
    hero: HeroStyle.none,
    cardScale: 0.82,
    radius: 8,
    focus: FocusStyle.outline,
    headingSize: 18,
    rowGap: 20,
    cardGap: 14,
  ),
  AppLayout(
    id: 'magazine',
    name: 'Magazine',
    nameDe: 'Magazin',
    description: 'Editorial: serif headlines, split cover story, sharp corners.',
    descriptionDe: 'Wie eine Zeitschrift: Serifen-Titel, Titelgeschichte, klare Kanten.',
    nav: NavStyle.top,
    hero: HeroStyle.split,
    heroHeight: 0.72,
    radius: 2,
    focus: FocusStyle.lift,
    headingFont: 'Georgia',
    headingSize: 26,
    headingWeight: FontWeight.w400,
    headingSpacing: 0,
    rowGap: 38,
    cardGap: 22,
  ),
  AppLayout(
    id: 'minimal',
    name: 'Minimal',
    nameDe: 'Minimal',
    description: 'No banner, no clutter – just your titles and space to breathe.',
    descriptionDe: 'Kein Banner, nichts Überflüssiges – nur deine Titel und viel Luft.',
    nav: NavStyle.minimal,
    hero: HeroStyle.none,
    cardScale: 0.95,
    radius: 6,
    cardTitles: false,
    focus: FocusStyle.outline,
    headingSize: 15,
    headingWeight: FontWeight.w600,
    uppercaseHeadings: true,
    headingSpacing: 2.2,
    rowGap: 44,
  ),
  AppLayout(
    id: 'retro',
    name: 'Retro VHS',
    nameDe: 'Retro VHS',
    description: 'Tube TV glow, scanlines and typewriter type.',
    descriptionDe: 'Röhren-Leuchten, Bildzeilen und Schreibmaschinenschrift.',
    nav: NavStyle.top,
    hero: HeroStyle.banner,
    heroHeight: 0.64,
    radius: 0,
    focus: FocusStyle.glow,
    bodyFont: 'Consolas',
    headingSize: 20,
    uppercaseHeadings: true,
    headingSpacing: 1.5,
    rowGap: 30,
    retro: true,
  ),
];

AppLayout layoutById(String id) => appLayouts.firstWhere((l) => l.id == id, orElse: () => appLayouts.first);

/// Aktives Layout (wird aus den Einstellungen gesetzt).
AppLayout appLayout = appLayouts.first;
