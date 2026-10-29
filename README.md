# Turbo Pip

Jeu de plateforme « runner » pour mobile, fait avec **Godot 4.7** (GDScript).
Pip court tout seul : tu touches l'écran pour sauter, tu maintiens pour sauter plus haut et tu touches une deuxième fois en l'air pour faire un double saut.

## Contenu

- **6 mondes de 4 niveaux (24 niveaux)** : Prairie Douce, Grottes Cristal, Désert Solaire, Pics Gelés, Forteresse de Lave et Royaume des Nuages.
- **3 cristaux cachés par niveau**, un point de passage à mi-parcours et un portail d'arrivée.
- **Ennemis et pièges** : scarabées (on peut les écraser), oursins piquants, chauves-souris, pics, geysers de feu, plateformes qui tombent ou bougent, ressorts.
- **4 mini-jeux** : Course infinie, Chrono gemmes (60 s), Éclate-ballons et Coffres mystères.
- **Boutique** de 6 tenues pour Pip, achetées avec les gemmes.
- **Sauvegarde automatique** (`user://turbopip_save.json`), avec musique et bruitages générés par le code (aucun fichier audio).

Tout est dessiné et généré dans le code : le projet ne contient aucune image ni aucun son à importer.

## Ouvrir le projet

1. Installe **Godot 4.7** (version standard, pas .NET).
2. Dans le gestionnaire de projets, choisis **Importer** puis sélectionne `project.godot`.
3. Lance le jeu avec **F5**. Sur PC, la barre Espace ou la flèche du haut font sauter.

## Exporter en APK Android

1. Dans **Éditeur → Gérer les modèles d'export**, télécharge les modèles d'export 4.7.
2. Dans **Éditeur → Paramètres de l'éditeur → Export → Android**, renseigne le chemin du SDK Android et un keystore de debug (ou de release).
3. Dans **Projet → Exporter…**, le préréglage **Android** est déjà configuré (package `com.turbopip.game`, paysage, plein écran). Clique sur **Exporter le projet**.

## Organisation du code

| Fichier | Rôle |
|---|---|
| `scenes/main.tscn` | Scène principale (nœud `Main` avec le nœud de jeu `Game`) |
| `scripts/main.gd` | Menus, navigation (bouton retour Android), boutique, coffres, écrans de résultat |
| `scripts/game.gd` | Gameplay : physique à 120 Hz, collisions, ennemis, HUD, mini-jeu des ballons, dessin |
| `scripts/level_gen.gd` | Génération des niveaux par blocs (trous, murs, ennemis…) avec une graine fixe par niveau |
| `scripts/world_data.gd` | Données des mondes et des tenues |
| `scripts/pip_art.gd` | Dessin de Pip et des formes réutilisées |
| `scripts/pip_view.gd` | Aperçu animé de Pip dans les menus |
| `scripts/sfx.gd` | Autoload `Sfx` : synthétiseur des bruitages et de la musique |
| `scripts/save_data.gd` | Autoload `Save` : progression, gemmes, records |
