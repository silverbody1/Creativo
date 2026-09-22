# Feuille de route

Seize phases. Une seule est livrée : la première. Les suivantes sont décrites
pour que l'architecture actuelle ne les rende jamais difficiles à ajouter,
**pas** pour être développées par anticipation.

---

## 1. Foundations ✅ livrée

Modèle de données complet, navigation, design system, scènes, plans, budget,
planning, bibliothèque globale, données de démonstration, tests, documentation.

Voir [ARCHITECTURE.md](ARCHITECTURE.md).

---

## 2. Professional Writing

Éditeur de scénario digne de ce nom, en remplacement de la section Écriture.

- Formatage automatique au standard scénario : séquence, action, personnage, dialogue, parenthétique, transition.
- Navigation au clavier entre les types d'élément, sans souris.
- Mode plein écran sans distraction.
- Révisions colorées et historique des versions d'une scène.
- Comptage de pages et estimation de durée à partir du texte.
- Import et export Fountain.

*S'appuie sur* : `StoryScene.content`, déjà en place.

---

## 3. Music Video Timeline

Le clip musical n'a pas de scènes au sens narratif : il a une piste audio et
des moments.

- Import d'un fichier audio dans le projet.
- Forme d'onde et marqueurs posés sur la timeline.
- Association d'une scène à une plage temporelle du morceau.
- Paroles synchronisées et découpage par section (intro, couplet, refrain, pont).

*S'appuie sur* : AVFoundation, `StoryScene.estimatedDuration`, `MediaStore`.

---

## 4. Shot Designer

Conception visuelle du découpage.

- Plan au sol d'un décor : caméra, sujets, sources lumineuses.
- Axes, focales et champs de vision représentés à l'échelle.
- Liaison directe entre un schéma et un `Shot`.
- Export d'un plan de tournage imprimable.

*S'appuie sur* : `Shot`, `ProductionLocation`.

---

## 5. Storyboard & Pencil

- Vignettes par plan, en grille et en planche.
- Dessin à l'Apple Pencil sur iPad, avec calques.
- Import d'une photo de repérage comme fond de vignette.
- Export planche PDF.

*S'appuie sur* : PencilKit, PDFKit, `ReferenceAsset`, `MediaStore`.

---

## 6. Moodboard / Visual Board

La section Board, aujourd'hui en état vide.

- Canevas libre : images, couleurs, textes, liens.
- Palettes extraites automatiquement d'une image.
- Plusieurs boards par projet, un par intention.
- Partage d'un board en image ou en PDF.

*S'appuie sur* : `ReferenceAsset`, PhotosUI.

---

## 7. Location Scouting

- Carte des lieux du projet et de la bibliothèque.
- Photos de repérage par lieu, avec orientation et heure de prise de vue.
- Course du soleil à une date donnée, pour la golden hour.
- Fiches de repérage exportables.

*S'appuie sur* : MapKit, `ProductionLocation.latitude` / `longitude`, déjà présents.

---

## 8. Production Library

Extension de la bibliothèque globale au-delà des trois catégories actuelles.

- Accessoires, véhicules, costumes.
- Références réutilisables entre projets.
- Disponibilités et conflits entre productions.
- Étiquettes et collections.

*S'appuie sur* : le patron d'affectation existant, à dupliquer par catégorie.

---

## 9. Advanced Budget

- Modèles de budget par type de projet.
- Devis et factures rattachés à une ligne.
- Suivi des règlements et échéances.
- Multi-devises et TVA par taux.
- Export tableur.

*S'appuie sur* : `BudgetLine.taxRate` et `actualAmount`, déjà modélisés.

---

## 10. Scheduling

- Calendrier des journées de tournage.
- Dépouillement : quelles scènes, quels lieux, quelles personnes par jour.
- Détection des conflits de disponibilité.
- Regroupement automatique par lieu et par moment de la journée.

*S'appuie sur* : `ShootDay.scenes` et `ShootDay.people`, déjà déclarés.

---

## 11. Call Sheets

- Génération d'une feuille de service par journée.
- Horaires, adresses, contacts, météo, plan d'accès.
- Export PDF et envoi à l'équipe.
- Accusé de réception.

*S'appuie sur* : PDFKit, la phase 10.

---

## 12. Shooting Mode

Une interface pensée pour le plateau, pas pour le bureau.

- Liste de plans en très gros caractères.
- Marquage d'un plan comme tourné en un geste.
- Notes vocales et prises numérotées.
- Fonctionne sans réseau, synchronise ensuite.

*S'appuie sur* : `ShotStatus`, déjà en place.

---

## 13. AI Production Assistant

- Propositions de découpage à partir d'un texte.
- Suggestions de plans pour une scène.
- Estimation de budget à partir de projets comparables.
- Détection des incohérences de planning.

Aucune fonctionnalité d'IA n'est développée avant cette phase.

---

## 14. Collaboration & Cloud

- Synchronisation iCloud entre Mac, iPad et iPhone.
- Partage d'un projet avec un collaborateur.
- Commentaires par scène et par plan.
- Historique des modifications.

*S'appuie sur* : `cloudKitDatabase: .none` à basculer ; le schéma est déjà
compatible, toutes les propriétés ayant une valeur par défaut.

---

## 15. Export / Import

- Export PDF : scénario, shot list, budget, planning.
- Export tableur du budget.
- Import Fountain, Final Draft, CSV.
- Archive complète d'un projet, médias inclus.

---

## 16. iPhone Companion

- Consultation du planning et de la feuille de service du jour.
- Capture rapide d'une idée, d'une photo de repérage, d'une note vocale.
- Marquage des plans tournés depuis la poche.

*S'appuie sur* : le domaine est déjà séparé des vues, seule une couche de
présentation est à écrire.
