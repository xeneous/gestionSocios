# Configuración de CI/CD - SAO 2026

## Descripción General

Este proyecto tiene configurado un pipeline de CI/CD usando **GitHub Actions** y **Firebase Hosting** para desplegar automáticamente la aplicación web Flutter.

---

## 🔧 Componentes

### 1. GitHub Actions Workflow
**Archivo**: [.github/workflows/firebase-deploy.yml](../.github/workflows/firebase-deploy.yml)

#### Trigger (Disparadores)
El workflow se ejecuta automáticamente cuando:
- ✅ Se hace push a la rama `main`
- ✅ Se hace push a la rama `master`
- ✅ Se dispara manualmente desde GitHub Actions (workflow_dispatch)

#### Pasos del Pipeline

```yaml
1. Checkout code (Descargar código)
   - Clona el repositorio
   - Usa: actions/checkout@v4

2. Setup Flutter (Configurar Flutter)
   - Instala Flutter 3.38.5 stable
   - Usa: subosito/flutter-action@v2

3. Get dependencies (Obtener dependencias)
   - Ejecuta: flutter pub get
   - Descarga todas las dependencias del pubspec.yaml

4. Build web (Compilar para web)
   - Ejecuta: flutter build web --release
   - Genera los archivos estáticos en build/web/

5. Deploy to Firebase Hosting (Desplegar)
   - Sube los archivos a Firebase Hosting
   - Usa: FirebaseExtended/action-hosting-deploy@v0
   - Despliega al canal 'live' (producción)
```

---

### 2. Firebase Hosting
**Archivos de configuración**:
- [firebase.json](../firebase.json) - Configuración de hosting
- [.firebaserc](../.firebaserc) - ID del proyecto

#### Configuración Firebase Hosting

```json
{
  "hosting": {
    "public": "build/web",           // Carpeta de salida de Flutter
    "rewrites": [{                     // SPA routing
      "source": "**",
      "destination": "/index.html"
    }],
    "headers": [{                      // Cache para assets
      "source": "**/*.@(jpg|jpeg|gif|png|svg|webp|js|css|eot|otf|ttf|ttc|woff|woff2|font.css)",
      "headers": [{
        "key": "Cache-Control",
        "value": "max-age=604800"      // 7 días
      }]
    }]
  }
}
```

**Proyecto Firebase**: `saoweb-7e02a`

---

## 🚀 Cómo Funciona

### Flujo Automático

```
1. Developer hace push a main/master
           ↓
2. GitHub Actions detecta el push
           ↓
3. Inicia el runner de Ubuntu
           ↓
4. Instala Flutter 3.38.5
           ↓
5. Descarga dependencias (pub get)
           ↓
6. Compila la app web (flutter build web)
           ↓
7. Despliega a Firebase Hosting
           ↓
8. App disponible en producción
```

### URLs de Despliegue

- **Producción**: `https://saoweb-7e02a.web.app`
- **Alternativa**: `https://saoweb-7e02a.firebaseapp.com`

---

## 🔐 Secrets Requeridos

El workflow necesita estos secrets configurados en GitHub:

### 1. `GITHUB_TOKEN`
- ✅ **Automático** - GitHub lo provee automáticamente
- Usado para autenticación básica

### 2. `FIREBASE_SERVICE_ACCOUNT`
- ⚠️ **Debe configurarse manualmente**
- Clave de cuenta de servicio de Firebase
- Se obtiene desde: Firebase Console → Project Settings → Service Accounts

#### Cómo obtener la Service Account:

1. Ve a [Firebase Console](https://console.firebase.google.com)
2. Selecciona el proyecto `saoweb-7e02a`
3. Ve a **Project Settings** (⚙️)
4. Pestaña **Service Accounts**
5. Click en **Generate new private key**
6. Descarga el archivo JSON
7. Copia el contenido completo del JSON
8. Ve a GitHub → Settings → Secrets and variables → Actions
9. Crea un nuevo secret llamado `FIREBASE_SERVICE_ACCOUNT`
10. Pega el contenido del JSON

---

## 📝 Cómo Usar

### Despliegue Automático
```bash
# 1. Hacer cambios en el código
git add .
git commit -m "feat: nueva funcionalidad"

# 2. Push a la rama main
git push origin main

# 3. El CI/CD se dispara automáticamente
# 4. Ver el progreso en GitHub Actions
# 5. Cuando termine, la app estará desplegada
```

### Despliegue Manual
Desde GitHub:
1. Ve a **Actions**
2. Selecciona **Deploy to Firebase Hosting**
3. Click en **Run workflow**
4. Selecciona la rama (main/master)
5. Click en **Run workflow** (botón verde)

### Despliegue Local (sin CI/CD)
```bash
# Compilar
flutter build web --release

# Desplegar (requiere Firebase CLI)
firebase deploy --only hosting
```

---

## 🐛 Troubleshooting

### Error: "Flutter version not found"
**Causa**: Versión de Flutter incorrecta
**Solución**: Actualizar el workflow con la versión correcta

```yaml
# En .github/workflows/firebase-deploy.yml
- name: Setup Flutter
  uses: subosito/flutter-action@v2
  with:
    flutter-version: '3.24.0'  # Actualizar a la versión actual
    channel: 'stable'
```

### Error: "Permission denied firebase-service-account"
**Causa**: Secret `FIREBASE_SERVICE_ACCOUNT` no configurado
**Solución**: Seguir los pasos en "Cómo obtener la Service Account"

### Error: "Build failed"
**Causa**: Error de compilación en el código
**Solución**:
1. Correr localmente: `flutter build web --release`
2. Verificar errores de compilación
3. Corregir antes de hacer push

### El despliegue funciona pero la app no carga
**Causa**: Posible error en la configuración de rewrites
**Solución**: Verificar que `firebase.json` tenga:
```json
"rewrites": [{
  "source": "**",
  "destination": "/index.html"
}]
```

---

## 📊 Monitoreo

### Ver el estado del despliegue
1. Ve a **GitHub Actions**
2. Selecciona el último workflow
3. Ver logs de cada paso
4. ✅ = Éxito | ❌ = Error

### Ver la app desplegada
- Firebase Console → Hosting
- Ver historial de despliegues
- Ver métricas de uso

---

## ⚙️ Configuración Avanzada

### Agregar stage/preview
Modificar el workflow para desplegar a un canal de preview:

```yaml
# En firebase-deploy.yml
- name: Deploy to Firebase Hosting Preview
  uses: FirebaseExtended/action-hosting-deploy@v0
  with:
    repoToken: ${{ secrets.GITHUB_TOKEN }}
    firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
    channelId: preview  # Canal de preview
    expires: 7d         # Expira en 7 días
    projectId: saoweb-7e02a
```

### Agregar tests antes del deploy

```yaml
# Agregar antes del build
- name: Run tests
  run: flutter test

- name: Run analyzer
  run: flutter analyze
```

### Cache de dependencias
```yaml
- name: Cache Flutter dependencies
  uses: actions/cache@v3
  with:
    path: |
      ~/.pub-cache
      .dart_tool
    key: ${{ runner.os }}-pub-${{ hashFiles('**/pubspec.lock') }}
    restore-keys: |
      ${{ runner.os }}-pub-
```

---

## 📚 Recursos

- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [Firebase Hosting Docs](https://firebase.google.com/docs/hosting)
- [Flutter Web Deployment](https://docs.flutter.dev/deployment/web)
- [Firebase Action Hosting Deploy](https://github.com/FirebaseExtended/action-hosting-deploy)

---

## ✅ Checklist de Verificación

Antes de hacer push a producción:

- [ ] Código compilado localmente sin errores
- [ ] Tests pasando (si existen)
- [ ] Flutter analyzer sin warnings críticos
- [ ] Versión de Flutter correcta en el workflow
- [ ] Secrets configurados en GitHub
- [ ] Firebase project ID correcto en firebase.json
- [ ] Probado en ambiente local con `flutter build web`

---

## 🔄 Actualización del Workflow

Última actualización: Enero 2026
Flutter version: 3.38.5
Firebase project: saoweb-7e02a
