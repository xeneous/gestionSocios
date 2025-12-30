# gestionSocios
# SAO 2026 - Sistema Contable Web

Sistema contable para la Sociedad Argentina de Oftalmología desarrollado en Flutter Web + Supabase.

## 🚀 Configuración Inicial

### 1. Crear Proyecto Supabase

1. Ve a [supabase.com](https://supabase.com)
2. Crea una nueva organización (si no tienes una)
3. Crea un nuevo proyecto llamado "SAO-2026"
4. Espera a que el proyecto se inicialice (2-3 minutos)

### 2. Ejecutar Schema PostgreSQL

1. En Supabase, ve a **SQL Editor**
2. Copia el contenido de `database/schema_postgresql.sql`
3. Ejecuta el script completo
4. Verifica que se crearon las 31 tablas

### 3. Configurar Credenciales

1. En Supabase, ve a **Settings** > **API**
2. Copia:
   - **Project URL**
   - **anon/public key**
3. Edita `lib/main.dart` y reemplaza:
   ```dart
   url: 'YOUR_SUPABASE_URL',        // Tu Project URL
   anonKey: 'YOUR_SUPABASE_ANON_KEY', // Tu anon key
   ```

### 4. Ejecutar la Aplicación

```bash
flutter run -d chrome
```

## 📁 Estructura del Proyecto

```
lib/
├── main.dart                          # Punto de entrada
├── core/
│   └── router/
│       └── app_router.dart            # Configuración de rutas
├── features/
│   ├── auth/                          # Autenticación
│   │   └── presentation/
│   │       ├── pages/
│   │       │   └── login_page.dart
│   │       └── providers/
│   │           └── auth_provider.dart
│   └── dashboard/                     # Dashboard
│       └── presentation/
│           └── pages/
                └── dashboard_page.dart
```

## 🔐 Autenticación

Para crear tu primer usuario:

1. Ve a Supabase > **Authentication** > **Users**
2. Click en **Add user** > **Create new user**
3. Ingresa email y contraseña
4. Usa estas credenciales en el login

## 📝 Próximos Pasos (Semanas 2-8)

- **Semana 2-3**: Módulos de Cuentas y Asientos
- **Semana 4-5**: Gestión de Socios y Facturación
- **Semana 5-6**: Compras y Ventas
- **Semana 7-8**: Reportes y Deploy

## 🛠️ Tecnologías

- **Flutter Web** - Framework UI
- **Supabase** - Backend (PostgreSQL + Auth)
- **Riverpod** - State Management
- **GoRouter** - Routing
- **Material 3** - Design System
