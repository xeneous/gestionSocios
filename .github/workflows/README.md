# GitHub Actions Workflows

Este directorio contiene los workflows de CI/CD para el proyecto SAO.

## Workflows Disponibles

### `firebase-deploy.yml`

Deployment automático a Firebase Hosting.

**Trigger**: Push a rama `main` o `master`, o ejecución manual

**Pasos**:
1. Checkout del código
2. Setup de Flutter 3.38.5
3. Instalación de dependencias
4. Build de la aplicación web
5. Deploy a Firebase Hosting

**Secretos requeridos**:
- `FIREBASE_SERVICE_ACCOUNT`: Cuenta de servicio de Firebase (JSON)

## Configuración Inicial

### 1. Crear Service Account en Firebase

1. Ve a Firebase Console > Project Settings > Service Accounts
2. Click "Generate new private key"
3. Descarga el archivo JSON

### 2. Agregar Secret a GitHub

1. Ve a tu repositorio en GitHub
2. Settings > Secrets and variables > Actions
3. Click "New repository secret"
4. Name: `FIREBASE_SERVICE_ACCOUNT`
5. Value: Pega todo el contenido del archivo JSON descargado
6. Click "Add secret"

### 3. Primera Ejecución

Después de configurar los secretos:
1. Haz un commit y push a `main`
2. Ve a la pestaña "Actions" en GitHub
3. Verás el workflow ejecutándose
4. Espera 2-5 minutos para que complete

## Ejecución Manual

Puedes ejecutar el workflow manualmente desde:
- GitHub > Actions > Deploy to Firebase Hosting > Run workflow

## Troubleshooting

### Error: "Secret not found"
- Verifica que `FIREBASE_SERVICE_ACCOUNT` esté configurado correctamente
- Asegúrate de que el JSON sea válido

### Error en Flutter Build
- Verifica que la versión de Flutter en el workflow coincida con tu versión local
- Revisa los logs en la pestaña Actions

### Deploy falla
- Verifica que el Project ID en el workflow sea correcto (`saoweb-7e02a`)
- Asegúrate de que la service account tenga permisos de Firebase Hosting
