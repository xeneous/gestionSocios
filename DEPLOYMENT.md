# Deployment de SAO 2026 a Firebase Hosting

Este documento describe cómo publicar la aplicación en Firebase Hosting.

## Configuración Inicial

### 1. Instalar Firebase CLI

```bash
npm install -g firebase-tools
```

### 2. Login a Firebase

```bash
firebase login
```

### 3. Crear Proyecto en Firebase Console

1. Ir a https://console.firebase.google.com
2. Crear nuevo proyecto
3. Copiar el Project ID y actualizar `.firebaserc`

## Build y Deploy

### Compilar la aplicación

```bash
flutter clean
flutter pub get
flutter build web --release --web-renderer html
```

### Deploy a Firebase

```bash
firebase deploy --only hosting
```

## URLs

Después del deploy, la app estará disponible en:
- `https://[PROJECT-ID].web.app`
- `https://[PROJECT-ID].firebaseapp.com`

## Configuración Opcional

### Dominio Personalizado

En Firebase Console > Hosting > Add custom domain

### Continuous Deployment con GitHub Actions

**AUTOMÁTICO**: El proyecto incluye un workflow de GitHub Actions que despliega automáticamente a Firebase Hosting cuando haces push a `main`.

#### Configuración inicial (una sola vez):

1. **Crear repositorio en GitHub** (si no existe)
2. **Generar Service Account**:
   - Ve a [Firebase Console](https://console.firebase.google.com) > Tu proyecto > Project Settings
   - Click en "Service Accounts" tab
   - Click "Generate new private key"
   - Descarga el archivo JSON
3. **Agregar secret a GitHub**:
   - Ve a tu repo > Settings > Secrets and variables > Actions
   - Click "New repository secret"
   - Name: `FIREBASE_SERVICE_ACCOUNT`
   - Value: Pega TODO el contenido del JSON descargado
   - Save

**¡Listo!** Ahora cada push a `main` automáticamente:
- Compila la app Flutter
- La despliega a Firebase Hosting
- Toma ~2-5 minutos

Ver detalles en [.github/workflows/README.md](.github/workflows/README.md)

## Notas

- El build se genera en `build/web`
- La configuración de Supabase está hardcoded en `lib/main.dart`
- Firebase Hosting tier gratuito: 10GB storage + 360MB/día transfer

