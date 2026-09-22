# Creativo

Studio de création et de préproduction audiovisuelle, natif Apple.

Creativo couvre la chaîne complète d'un projet vidéo — idée, écriture, scènes,
découpage, plans, lieux, équipe, matériel, budget, planning — dans une seule
application SwiftUI partagée entre **macOS** et **iPadOS**.

Ce dépôt contient les phases **1 — Fondations** et **2 — Écriture professionnelle**.

## Prérequis

| | |
|---|---|
| Xcode | 15.0 ou plus récent |
| macOS (pour développer) | 14 Sonoma ou plus récent |
| macOS (pour exécuter) | 14 Sonoma |
| iPadOS (pour exécuter) | 17 |

Aucun compte développeur, aucun entitlement iCloud et aucune dépendance
externe ne sont nécessaires. Xcode signe l'application localement.

## Démarrer

```bash
git clone https://github.com/silverbody1/Creativo.git
cd Creativo
open Creativo.xcodeproj
```

Dans Xcode, choisissez la destination **My Mac** puis ⌘R.
Pour l'iPad, choisissez un simulateur iPad.

En ligne de commande :

```bash
# Compiler pour macOS
xcodebuild -scheme Creativo -destination 'platform=macOS' build

# Compiler pour iPadOS
xcodebuild -scheme Creativo -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build

# Lancer les tests
xcodebuild -scheme Creativo -destination 'platform=macOS' test
```

## Ce qui fonctionne

Toutes les données ci-dessous sont **réellement persistées** avec SwiftData.
Rien n'est simulé.

- **Accueil** — accueil contextuel, projet à reprendre, projets récents, favoris, état vide.
- **Projets** — création guidée par type, recherche, affichage grille ou liste, favoris, statut, suppression confirmée.
- **Workspace de projet** — barre latérale interne avec compteurs, onze sections.
- **Vue d'ensemble** — identité du projet, six cartes de chiffres clés, liste « À préparer » déduite des données.
- **Écriture** — trois surfaces selon le type de projet : éditeur de scénario, script YouTube, structure de clip. Mode focus, annuler/refaire, autosave.
- **Scènes** — création, édition, réordonnancement, renumérotation, recherche, suppression confirmée.
- **Plans** — regroupés par scène, progression « X / Y plans tournés », statut en un clic, réordonnancement.
- **Budget** — cible, prévisionnel, dépensé, restant, lignes groupées par catégorie, TVA, montant réellement payé, écart.
- **Planning** — journées de tournage avec date, convocation, fin estimée et notes.
- **Bibliothèque globale** — personnes, lieux et matériel, réutilisables sur plusieurs projets, avec recherche.
- **Affectations** — une personne ou un matériel se rattache à un projet avec son rôle, ses jours et son tarif propres.
- **Réglages** — thème clair / sombre / système, état de la bibliothèque, chargement des données de démonstration (builds de développement uniquement).

### Raccourcis clavier

| Raccourci | Action |
|---|---|
| ⌘N | Nouveau projet |
| ⌘S | Enregistrer |
| ⌘F | Rechercher un projet |
| ⌘, | Réglages |
| ⌘1 … ⌘4 | Accueil, Projets, Favoris, Bibliothèque |
| ⌘⇧W | Fermer le projet ouvert |
| ⌘[ | Revenir aux projets depuis un workspace |
| ⌘⇧N | Nouvelle scène dans l'éditeur de scénario |
| ⌘⇧F | Entrer ou sortir du mode focus |
| ⌘1 … ⌘6 | Type de la ligne de scénario en cours |
| ⌘↩ | Nouvelle ligne de scénario |
| Échap | Quitter le mode focus |

## Ce qui n'est pas encore là

Board visuel et documents sont présents dans la navigation avec un véritable
écran d'état vide, mais leur fonctionnalité appartient à une phase dédiée.
Côté écriture, les révisions colorées, l'historique des versions et l'import
ou export Fountain viendront plus tard, comme la forme d'onde audio du clip.
Voir [docs/ROADMAP.md](docs/ROADMAP.md).

## Organisation du dépôt

```
Creativo/
  App/              point d'entrée, coquille de navigation, commandes clavier
  Core/             persistance et état de navigation
  DesignSystem/     jetons visuels et composants réutilisables
  Models/           entités SwiftData et énumérations du domaine
  Features/         un dossier par écran, dont Writing/ et ses trois surfaces
  Services/         règles métier, sans SwiftUI
  Utilities/        formatage, bindings, adaptations par plateforme
  PreviewContent/   données de démonstration
CreativoTests/      tests unitaires
Config/             entitlements
Scripts/            génération du projet Xcode
docs/               architecture et feuille de route
```

## Ajouter des fichiers

Le fichier `Creativo.xcodeproj/project.pbxproj` est **généré**. Après avoir
ajouté, déplacé ou supprimé un fichier source :

```bash
python3 Scripts/generate_project.py
```

La génération est déterministe : relancer le script sans changement ne produit
aucune différence.

## Documentation

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — modèle de données, choix techniques, conventions.
- [docs/ROADMAP.md](docs/ROADMAP.md) — les seize phases prévues.
