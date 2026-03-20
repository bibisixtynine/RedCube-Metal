# metalJS: RealityKit + JavaScript Playground

## Présentation du Projet
metalJS est un environnement de prototypage 3D pour macOS qui fusionne la puissance de **RealityKit** avec la souplesse du moteur **QuickJS**. Il permet de créer des scènes 3D interactives en temps réel via un éditeur de code intégré.

## Architecture
L'application repose sur trois piliers :
1. **Interface macOS (SwiftUI)** : Un éditeur de code live avec rendu 3D côte à côte.
2. **Moteur RealityKit** : Gestion native des entités, de la physique, des ombres et du rendu premium (coins arrondis, PBR).
3. **Bridge C/JavaScript (QuickJS)** : Une couche ultra-rapide permettant d'exécuter du JS à 60 FPS avec accès direct aux fonctionnalités de RealityKit.

## API JavaScript
Le SDK expose les fonctions suivantes :

- `spawn(type, name?)` : Crée une entité (`'box'`, `'sphere'`, `'plane'`).
- `setPosition(id, x, y, z)` : Définit la position dans l'espace.
- `setRotation(id, x, y, z)` : Oriente l'objet (Euler en radians).
- `setScale(id, x, y, z)` : Redimensionne l'objet.
- `setColor(id, r, g, b, a, met?, rough?)` : Applique une couleur PBR (métallique/rugosité).
- `setPhysics(id, mode)` : Active la physique (`'static'` ou `'dynamic'`).
- `setTexture(id, name)` : Applique une texture depuis les ressources.
- `remove(id)` : Supprime l'entité.
- `setCamera(...)` : Contrôle la vue caméra.
- `requestAnimationFrame(callback)` : Boucle de rendu standard.

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
