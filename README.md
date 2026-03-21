# metalJS: RealityKit + JavaScript Playground

## Présentation du Projet
metalJS est un environnement de prototypage 3D pour macOS qui fusionne la puissance de **RealityKit** avec la souplesse du moteur **QuickJS**. Il permet de créer des scènes 3D interactives en temps réel via un éditeur de code intégré.

## Architecture
L'application repose sur trois piliers :
1. **Interface macOS (SwiftUI)** : Un éditeur de code live avec rendu 3D côte à côte.
2. **Moteur RealityKit** : Gestion native des entités, de la physique, des ombres et du rendu premium (coins arrondis, PBR).
3. **Bridge C/JavaScript (QuickJS)** : Une couche ultra-rapide permettant d'exécuter du JS à 60 FPS avec accès direct aux fonctionnalités de RealityKit.

## API JavaScript
Le moteur supporte une syntaxe **Objet-Orientée** moderne et fluide grâce au chaînage des méthodes :

```javascript
let cube = spawn('box')
    .setPosition(0, 0, 0)
    .setScale(2, 2, 2)
    .setColor(1, 0, 0, 1) // Rouge Purer PBR
```

### Méthodes d'Entité
- `entity.setPosition(x, y, z)` : Définit la position dans l'espace.
- `entity.setRotation(x, y, z)` : Oriente l'objet (Euler en radians).
- `entity.setScale(x, y, z)` : Redimensionne l'objet.
- `entity.setColor(r, g, b, a, met?, rough?)` : Applique une couleur PBR (métallique/rugosité).
- `entity.setPhysics(mode)` : Définit la physique (`'static'`, `'dynamic'`, `'kinematic'`).
- `entity.setTexture(name)` : Applique une texture depuis les ressources.
- `entity.lock()` / `entity.unlock()` : Verrouille/déverrouille l'interaction à la souris.
- `entity.remove()` : Supprime l'entité de la scène.

### Fonctions Globales
- `spawn(type, name?)` : Crée une entité et retourne un objet interactif.
- `setCamera(x, y, z, tx, ty, tz)` : Contrôle la vue caméra native.
- `requestAnimationFrame(callback)` : Boucle de frame standard.

## Interactions Trackpad
Vous pouvez écouter les événements système via le hook global :
```javascript
globalThis._onEvent = function(type, x, y) {
    // type: 'drag', 'zoom', 'scroll'
}
```

## Compilation
Utilisez le script `build.sh` pour compiler l'application :
```bash
./build.sh
```
Nécessite les **Command Line Tools** de macOS.
