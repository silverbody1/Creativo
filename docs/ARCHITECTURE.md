# Architecture

Ce document décrit comment Creativo est construit et quelles règles doivent
être respectées lors des prochaines phases.

## 1. Principes

1. **SwiftData est la source de vérité.** Rien d'important ne vit uniquement en mémoire.
2. **Les vues n'appliquent pas de règles métier.** Elles lisent le modèle et appellent un service.
3. **Aucune dépendance externe.** Uniquement les frameworks Apple.
4. **Le build ne dépend d'aucun compte ni entitlement.** CloudKit est explicitement désactivé.
5. **Cross-platform par construction.** Chaque `#if os(...)` vit dans `Utilities/PlatformModifiers.swift`, jamais dans un écran.
6. **Rien de codé en dur côté couleurs.** Toutes les surfaces dérivent de `Color.primary`, ce qui garantit le mode sombre.

## 2. Organisation du projet

```
Creativo/
├── App/
│   ├── CreativoApp.swift        @main, construction du ModelContainer, scène Réglages macOS
│   ├── RootView.swift           bascule coquille ↔ workspace, thème, feuille « Nouveau projet »
│   ├── MainShellView.swift      NavigationSplitView principal
│   └── AppCommands.swift        menus et raccourcis clavier
├── Core/
│   ├── Persistence/
│   │   ├── PersistenceController.swift   schéma et fabriques de conteneurs
│   │   └── MediaStore.swift              dossier des médias importés
│   └── Navigation/
│       ├── AppState.swift                état de navigation observable
│       ├── SidebarDestination.swift      sections de la coquille
│       ├── WorkspaceSection.swift        sections d'un projet
│       └── AppAppearance.swift           thème clair / sombre / système
├── DesignSystem/
│   ├── DesignSystem.swift       Spacing, CornerRadius, LayoutMetrics, Surface
│   ├── Tints.swift              couleur associée à chaque énumération du domaine
│   ├── ScreenplayStyle.swift    typographie et marges du format scénario
│   └── Components/              EmptyStateView, StatCard, Chip, SectionHeaderView, …
├── Models/                      entités SwiftData + énumérations
│   └── Writing/                 modes d'écriture et facettes
├── Features/                    un dossier par écran
│   └── Writing/                 les trois surfaces d'écriture
├── Services/                    règles métier pures, sans SwiftUI
│   └── Writing/                 scénario, script vidéo, structure de clip
├── Utilities/                   formatage, bindings, adaptations plateforme
└── PreviewContent/SampleData.swift
```

La règle de dépendance est à sens unique :

```
Features  →  Services  →  Models
    ↓            ↓
DesignSystem  Utilities
```

Un modèle n'importe jamais SwiftUI. Un service n'importe jamais SwiftUI.
Une vue n'écrit jamais dans le `ModelContext` sans passer par un service,
à l'exception des liaisons `@Bindable` d'un formulaire, qui sont validées
et horodatées par l'appel `commitEdits` correspondant.

## 3. Modèle de données

### Vue d'ensemble

```
                    ┌──────────────┐
                    │   Project    │
                    └──────┬───────┘
      ┌────────────┬───────┼─────────┬──────────────┬─────────────┐
      │ cascade    │       │         │              │             │
┌─────▼─────┐ ┌────▼─────┐ │  ┌──────▼──────┐ ┌─────▼────────┐    │ nullify
│StoryScene │ │BudgetLine│ │  │  ShootDay   │ │ReferenceAsset│    │
└─────┬─────┘ └──────────┘ │  └─────────────┘ └──────────────┘    │
      │ cascade            │                                       │
┌─────▼─────┐              │ cascade                    ┌──────────▼─────────┐
│   Shot    │              ├──────────────┐             │ ProductionLocation │
└───────────┘              │              │             └────────────────────┘
                 ┌─────────▼──────────┐ ┌─▼───────────────────────────┐
                 │ProjectPersonAssign.│ │ProjectEquipmentAssignment   │
                 └─────────┬──────────┘ └─┬───────────────────────────┘
                           │ cascade      │ cascade
                    ┌──────▼─────┐   ┌────▼──────────┐
                    │   Person   │   │ EquipmentItem │
                    └────────────┘   └───────────────┘
                     bibliothèque      bibliothèque
```

### Entités

| Entité | Rôle | Appartenance |
|---|---|---|
| `Project` | Agrégat racine d'une production | — |
| `StoryScene` | Une scène | appartient au projet |
| `Shot` | Un plan | appartient à la scène |
| `BudgetLine` | Une ligne budgétaire | appartient au projet |
| `ShootDay` | Une journée de tournage | appartient au projet |
| `ReferenceAsset` | Une référence visuelle ou sonore | appartient au projet |
| `Person` | Une personne | **bibliothèque globale** |
| `ProductionLocation` | Un lieu | **bibliothèque globale** |
| `EquipmentItem` | Un matériel | **bibliothèque globale** |
| `ProjectPersonAssignment` | Jointure projet ↔ personne | appartient aux deux |
| `ProjectEquipmentAssignment` | Jointure projet ↔ matériel | appartient aux deux |
| `ScreenplayElement` | Une ligne typée de scénario | appartient à la scène |
| `MusicVideoFacet` | La face clip d'une scène | appartient à la scène |
| `YouTubeBlock` | Un bloc de script vidéo | appartient au projet |

### La bibliothèque globale

C'est le concept central du produit. Une personne, un lieu ou un matériel
n'appartient **jamais** à un projet : il est référencé. Supprimer un projet ne
retire donc jamais un contact de votre carnet d'adresses.

La participation passe par un modèle de jointure qui porte tout ce qui est
propre au projet : le rôle tenu sur *cette* production, le tarif négocié, le
nombre de jours, les quantités. C'est ce qui permet à une même chef opératrice
d'être à 450 € par jour sur un clip et à 600 € sur une publicité, sans
dupliquer sa fiche.

### Règles de suppression

| Action | Effet |
|---|---|
| Supprimer un projet | scènes, plans, lignes budgétaires, journées, références et affectations supprimés ; bibliothèque intacte |
| Supprimer une scène | ses plans supprimés, les scènes suivantes renumérotées |
| Supprimer une personne | ses affectations supprimées, les projets intacts |
| Supprimer un lieu | retiré des projets, les scènes concernées perdent leur lieu |
| Retirer du projet | seule l'affectation disparaît, l'élément reste en bibliothèque |

Ces règles sont couvertes par `CreativoTests/DeletionTests.swift`.

### Deux décisions de nommage

- **`StoryScene` et non `Scene`.** `Scene` est un protocole SwiftUI ; le
  masquer rend ambigu le `body` de toute structure `App`. Le vocabulaire
  utilisateur reste « scène ».
- **`ProductionLocation` et non `Location`.** Évite la collision avec
  CoreLocation, qui sera utilisé lors de la phase de repérage.

### L'argent est un `Decimal`

Tous les montants sont des `Decimal`, jamais des `Double`. La virgule flottante
binaire ne représente pas exactement 0,10 et la dérive devient visible dès
quelques dizaines de lignes additionnées. Le taux de TVA par défaut est
construit par division (`Decimal(20) / Decimal(100)`) et non depuis un littéral
flottant, pour la même raison.

### Les binaires restent hors du store

`ReferenceAsset` et `Project.coverImagePath` ne stockent qu'un chemin.
`MediaStore` possède le dossier `Application Support/Creativo/Media`. Mettre
des images dans le store ralentirait chaque lecture et rendrait la
synchronisation iCloud irréaliste.

## 4. L'espace Écriture

L'écriture n'est pas un écran de plus : c'est trois surfaces qui partagent la
même colonne vertébrale.

### La règle : une seule colonne vertébrale

`StoryScene` reste l'unité de découpage de **tous** les types de projet. Les
modes d'écriture ne créent pas de scènes parallèles, ils s'y accrochent.

```
                       ┌──────────────┐
                       │   Project    │
                       └──────┬───────┘
              youtubeBlocks   │   scenes
        ┌──────────────────┐  │  ┌─────────────────┐
        │  YouTubeBlock    │  │  │   StoryScene    │
        │  (script vidéo)  │  │  └────────┬────────┘
        └────────┬─────────┘  │           │
                 │ scene?     │     ┌─────┴──────┐
                 └────────────┼────▶│            │
                              │     ▼            ▼
                        ScreenplayElement   MusicVideoFacet
                        (film, pub)         (clip)
```

| Mode | Ce qui est écrit | Où c'est rangé |
|---|---|---|
| Scénario | Lignes typées : action, personnage, dialogue, parenthèse, transition, note | `ScreenplayElement`, enfants de la scène |
| Script YouTube | Blocs : accroche, intro, chapitre, A-roll, B-roll, voix off, appel à l'action, note de montage, source | `YouTubeBlock`, enfants du projet |
| Clip musical | Sections du morceau : type, timecode, paroles, idée visuelle, registre, tenues, accessoires, distribution | `MusicVideoFacet`, accroché 1 à 1 à une scène |

Pourquoi le script YouTube fait exception : un script vidéo est un plan de
rédaction, pas un découpage. L'y forcer produirait des scènes vides. Un bloc
qui mérite une vraie scène — une liste de plans, un lieu, une journée de
tournage — est **promu** en `StoryScene` d'un geste, et garde le lien. C'est
ce pont qui relie l'écriture au reste de la production sans l'imposer.

Pour le clip, l'inverse est vrai : une section *est* une scène. Le projet
d'exemple a des scènes Intro, Couplet 1, Refrain 1 depuis la phase 1 ; elles
reçoivent simplement leur facette, dont le type est déduit du titre. Aucune
donnée n'est dupliquée, et les plans, le lieu et le jour de tournage d'une
section sont ceux de la scène.

### Le mode d'écriture est choisi, pas subi

`Project.writingMode` vaut `writingModeOverride ?? type.defaultWritingMode`.
Le type de projet propose, l'utilisateur dispose, et **changer de mode ne
supprime jamais rien** : un projet peut porter un scénario, un script et une
structure de clip en même temps. C'est ce qui permettra à une phase ultérieure
d'activer plusieurs modes à la fois sans migrer quoi que ce soit.

### Ce que la scène ne perd jamais

`StoryScene.content` existe depuis la phase 1. Il n'a pas été supprimé :

- à la première ouverture de l'éditeur, un texte déjà saisi est **analysé** en
  lignes typées par `ScreenplayFormatter.parse` ; un paragraphe non reconnu
  devient une action, donc rien n'est jamais perdu ;
- ensuite, `content` est maintenu comme copie en texte brut de ce que
  l'éditeur affiche, ce qui garde l'écran Scènes, la recherche et les futurs
  exports cohérents.

L'import ne s'exécute qu'une fois par scène, et jamais sur une scène qui a
déjà des lignes.

### Pagination

`ScreenplayFormatter` compte les lignes d'une page de 12 pt Courier :
55 lignes, largeurs de colonne par type d'élément, ligne vide après une
action, un dialogue ou une transition. Les notes ne sont jamais imprimées.
Tout est pur et testé directement.

### Durée d'une vidéo

`ScriptMetricsCalculator` ne compte que les mots **réellement prononcés** :
un plan de B-roll, une note de montage ou une source ne se lisent pas à voix
haute. Le débit est réglable par projet, parce que deux présentateurs ne
parlent pas à la même vitesse.

### Annuler et refaire

`ModelContext.undoManager` est activé au lancement, ce qui rend réversible la
suppression d'une ligne, un changement de type ou une section retirée. Les
boutons vivent dans le menu de chaque éditeur ; ⌘Z reste l'annulation de
texte du système, pour ne pas voler un raccourci que tout le monde connaît.

### Mode focus

Le mode focus est une prise de contrôle de la fenêtre au niveau de `RootView`,
exactement comme l'ouverture d'un projet. Les deux barres latérales
disparaissent et il ne reste que la page. Ce choix évite un `overlay` qui se
comporterait différemment sur macOS et sur iPadOS.

## 5. Navigation

Deux niveaux, chacun étant un `NavigationSplitView` natif :

1. **La coquille** — Accueil, Tous les projets, Favoris, Bibliothèque, Réglages.
2. **Le workspace** — ouvert en plein écran quand un projet est sélectionné, avec sa propre barre latérale de onze sections.

Ouvrir un projet remplace la coquille plutôt que de pousser une vue dans la
colonne de détail. C'est ce qui donne au projet une vraie barre latérale sur
les deux plateformes, sans imbriquer deux `NavigationSplitView`.

`AppState` est un objet `@Observable` qui ne connaît **que** la navigation :
section sélectionnée, projet ouvert, feuille présentée. Aucune logique métier,
aucun `ModelContext`.

Chaque section reçoit une `NavigationStack` neuve via `.id(section)`, pour
qu'un éditeur poussé dans une section ne reste pas affiché après un changement
de section.

## 6. Adaptation macOS / iPadOS

`horizontalSizeClass` n'existe pas sur macOS. Les écrans qui changent de
disposition mesurent donc la largeur réelle de leur conteneur avec
`WidthReader`, ce qui fonctionne aussi sous Stage Manager et en multitâche iPad,
où la fenêtre peut avoir n'importe quelle largeur.

Les différences de plateforme sont concentrées dans
`Utilities/PlatformModifiers.swift` :

| Helper | macOS | iPadOS |
|---|---|---|
| `inlineNavigationTitle()` | sans effet | titre compact |
| `macSheetFrame(...)` | taille de fenêtre | sans effet |
| `numericKeyboard()` / `decimalKeyboard()` | sans effet | pavé numérique |
| `rawTextField()` | correction désactivée | correction et majuscules désactivées |

Les cibles tactiles passent par `.touchTarget()`, qui garantit 44 pt de hauteur
sans changer la taille visuelle.

## 7. Design system

Trois barèmes seulement, pour que toutes les pages se ressemblent :

- `Spacing` — `xxs` 2, `xs` 4, `sm` 8, `md` 12, `lg` 16, `xl` 24, `xxl` 32, `xxxl` 48
- `CornerRadius` — `small` 8, `medium` 12, `large` 16, `extraLarge` 22, `pill`
- `LayoutMetrics` — largeurs de barre latérale, seuil compact, largeur de lecture, cible tactile

Les surfaces (`Surface.card`, `Surface.separator`, …) sont des fractions de
`Color.primary`. Il n'y a donc **aucune valeur RGB à inverser** pour le mode
sombre : il fonctionne par construction. Les couleurs de domaine vivent dans
`DesignSystem/Tints.swift` sous forme d'extensions des énumérations, jamais
dans les modèles : le domaine n'a pas d'avis sur la couleur.

Tout écran sans contenu utilise `EmptyStateView`, y compris les sections pas
encore développées : elles expliquent ce qu'elles feront et proposent l'action
la plus utile en attendant.

## 8. Services

| Service | Responsabilité |
|---|---|
| `ProjectService` | création, statut, favori, suppression, filtrage |
| `SceneService` | création, ordre, renumérotation, suppression |
| `ShotService` | création, lettrage, statut, ordre, suppression |
| `BudgetService` | lignes budgétaires, budget cible |
| `BudgetCalculator` | arithmétique pure : totaux, catégories, ratios |
| `LibraryService` | bibliothèque et affectations |
| `ScheduleService` | journées de tournage |
| `ProjectInsights` | liste « À préparer », déterministe |
| `ScreenplayService` | lignes de scénario : création, type, ordre, import |
| `ScreenplayFormatter` | rendu en texte, pagination, analyse — pur |
| `YouTubeScriptService` | blocs de script, repli, promotion en scène |
| `ScriptMetricsCalculator` | mots et durée estimée — pur |
| `MusicVideoService` | sections de clip, facettes, distribution |
| `PersistenceActions` | enregistrement et journalisation |

`BudgetCalculator`, `ProjectInsights`, `ScreenplayFormatter` et
`ScriptMetricsCalculator` ne touchent ni à SwiftData ni à SwiftUI : ce sont des
fonctions pures, testées directement.

Les totaux ne sont **jamais** stockés. `Project.budgetSummary` est recalculé à
chaque lecture, si bien qu'éditer une ligne met à jour l'en-tête, le sous-total
de catégorie et le tableau de bord dans la même image.

## 9. Intégrations prévues

L'architecture actuelle ne bloque aucune des intégrations suivantes.

| Framework | Usage prévu | Ce qui est déjà en place |
|---|---|---|
| CloudKit | synchronisation multi-appareils | `cloudKitDatabase: .none` à changer en une ligne ; toutes les propriétés ont une valeur par défaut et aucune relation n'est obligatoire, ce qu'exige CloudKit |
| MapKit | repérage et carte des lieux | `latitude` et `longitude` optionnelles sur `ProductionLocation`, sans import CoreLocation |
| AVFoundation | timeline musicale, waveform | `estimatedDuration` en secondes sur les scènes |
| PencilKit | storyboard dessiné | `ReferenceAsset` et `MediaStore` référencent des fichiers |
| PhotosUI | import de couvertures et références | `coverImagePath`, `MediaStore.importFile` |
| PDFKit | feuilles de service, exports | `ShootDay` relié aux scènes et aux personnes |

## 10. Migrations

Le schéma n'évolue **que par ajout** : nouvelles entités, nouvelles propriétés
avec valeur par défaut, nouvelles relations initialisées à vide ou optionnelles.
SwiftData applique alors une migration légère automatiquement, et les données
déjà sur disque sont conservées telles quelles. C'est ainsi que la phase 2 a
ajouté trois entités et cinq propriétés sans qu'un projet existant perde une
ligne.

Le jour où une propriété devra être renommée, retypée ou supprimée, cette
garantie tombe : il faudra un `VersionedSchema` par version et un
`SchemaMigrationPlan` déclarant l'étape correspondante. Tant que la règle
additive tient, s'en passer est le choix le plus sûr.

Si malgré tout le store refuse de s'ouvrir, `PersistenceController` ne le
supprime jamais : il le **renomme** avec un horodatage et repart sur un store
neuf. Les données restent récupérables sur le disque et l'application se lance.

## 11. Conventions pour les prochaines phases

1. **Une nouvelle entité** s'ajoute dans `Models/`, puis dans
   `PersistenceController.schema`, puis dans `SampleData`. Les trois, sinon les
   previews cassent.
2. **Toute propriété a une valeur par défaut.** C'est la condition d'une
   migration légère et de CloudKit.
3. **Une nouvelle section de workspace** s'ajoute dans `WorkspaceSection`, dans
   l'un des trois groupes, et dans le `switch` de `ProjectWorkspaceView`. Tant
   que l'écran n'existe pas, `isImplemented` reste `false` et
   `ComingSoonSectionView` prend le relais.
4. **Aucune logique métier dans une vue.** Si une vue calcule autre chose qu'un
   affichage, la règle appartient à un service.
5. **Aucune couleur littérale.** Toute nouvelle teinte passe par `Tints.swift`.
6. **Aucun `#if os(...)` dans `Features/`.** Ajoutez un helper dans
   `PlatformModifiers.swift`.
7. **Régénérez le projet** avec `python3 Scripts/generate_project.py` après
   avoir ajouté un fichier.
8. **Chaque règle de suppression a un test.** C'est l'opération la plus risquée
   d'un modèle relationnel.
9. **Le schéma n'évolue que par ajout** tant qu'aucun `SchemaMigrationPlan`
   n'existe. Voir la section Migrations.
10. **Une nouvelle surface d'écriture** s'ajoute dans `WritingMode`, dans le
    `switch` de `WritingView`, et sous la forme d'une facette accrochée à
    `StoryScene` — jamais d'une liste de scènes parallèle.

## 12. Tests

`CreativoTests/` couvre :

- création de projet, nom par défaut, favori, statut, filtrage, tri
- arithmétique d'une ligne budgétaire, TVA, lignes annulées, écart
- agrégation du budget, totaux par catégorie, dépassement de cible
- relations projet ↔ scènes ↔ plans, ordre, renumérotation, lettrage
- une personne sur plusieurs projets, rôles et tarifs par projet
- toutes les règles de suppression et de détachement
- cohérence des données de démonstration et de la liste « À préparer »
- formatage des durées, cadences, compteurs et recherche sans accents
- rendu, pagination et analyse du scénario, import d'un texte déjà saisi
- ordre, typage et suppression des lignes de scénario
- blocs de script vidéo : repli, comptage, durée, promotion en scène
- sections de clip : facettes, déduction du type, timecodes, distribution
- le mode d'écriture suit le type de projet et n'efface rien quand il change

Chaque test reçoit son propre `ModelContainer` en mémoire via
`CreativoTestCase`, donc aucun test ne dépend d'un autre.
