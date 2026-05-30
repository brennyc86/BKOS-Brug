// Centrale kleurenpalet voor BKOS Brug
// Donkergroen met warme beige accenten

import 'package:flutter/material.dart';

// Achtergrond & oppervlakken
const kAchtergrond   = Color(0xFF0C1A0E); // zeer donker groen
const kOppervlak     = Color(0xFF142918); // donker groen kaartje
const kOppervlakHoog = Color(0xFF1C3D22); // iets lichter groen

// Primaire groen tinten
const kGroenPrimair  = Color(0xFF3A7A52); // medium bosgroen
const kGroenLicht    = Color(0xFF5BA370); // licht groen accent
const kGroenAan      = Color(0xFF6DC98A); // AAN-status indicator

// Beige tekst & randen
const kBeige         = Color(0xFFE8DCC8); // warm beige — primaire tekst
const kBeigeZacht    = Color(0xFFB8AA8A); // zachter beige — secundaire tekst
const kBeigeDim      = Color(0xFF7A6E58); // dim beige — placeholder
const kBeigeRand     = Color(0xFF3A3020); // donkere beige rand

// Statuskleuren
const kStatusAan     = Color(0xFF6DC98A); // groen
const kStatusUit     = Color(0xFF5A5A4A); // grijs-groen
const kStatusBlok    = Color(0xFFD4A030); // amber
const kStatusIngang  = Color(0xFF60C0C8); // blauw-groen

// NavBar
const kNavBar        = Color(0xFF0E2012); // donker navbalk

ThemeData bkosTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: kAchtergrond,
    cardColor: kOppervlak,
    colorScheme: const ColorScheme.dark(
      surface: kOppervlak,
      onSurface: kBeige,
      primary: kGroenPrimair,
      onPrimary: kBeige,
      secondary: kGroenLicht,
      onSecondary: kAchtergrond,
      tertiary: kBeigeZacht,
      outline: kBeigeRand,
      surfaceContainerHighest: kOppervlakHoog,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: kAchtergrond,
      foregroundColor: kBeige,
      elevation: 0,
    ),
    cardTheme: CardTheme(
      color: kOppervlak,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: kBeigeRand, width: 1),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: kNavBar,
      indicatorColor: kGroenPrimair.withOpacity(0.3),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(color: kBeigeZacht, fontSize: 11),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: kOppervlak,
      border: OutlineInputBorder(
        borderSide: BorderSide(color: kBeigeRand),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: kBeigeRand),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: kGroenPrimair, width: 2),
      ),
      labelStyle: TextStyle(color: kBeigeZacht),
      hintStyle: TextStyle(color: kBeigeDim),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kGroenPrimair,
        foregroundColor: kBeige,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kBeige,
        side: const BorderSide(color: kBeigeRand),
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge:  TextStyle(color: kBeige),
      bodyMedium: TextStyle(color: kBeige),
      bodySmall:  TextStyle(color: kBeigeZacht),
      titleLarge: TextStyle(color: kBeige, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: kBeige),
      labelSmall: TextStyle(color: kBeigeZacht, letterSpacing: 0.8),
    ),
    dividerTheme: const DividerThemeData(color: kBeigeRand),
  );
}
