# Setup Git y GitHub para SAO

Esta guía te ayudará a configurar Git y GitHub para habilitar el CI/CD automático.

## Pasos

### 1. Inicializar Git localmente

```bash
git init
git add .
git commit -m "Initial commit - SAO Web Application"
```

### 2. Crear repositorio en GitHub

1. Ve a https://github.com/new
2. Nombre del repositorio: `sao-web` (o el que prefieras)
3. Descripción: "Sistema de Gestión para SAO"
4. **NO** inicialices con README, .gitignore, o licencia (ya los tienes)
5. Click "Create repository"

### 3. Conectar local con GitHub

GitHub te mostrará comandos, pero usa estos (reemplaza `TU-USUARIO`):

```bash
git remote add origin https://github.com/TU-USUARIO/sao-web.git
git branch -M main
git push -u origin main
```

### 4. Configurar CI/CD (ver DEPLOYMENT.md)

Una vez que el código esté en GitHub, sigue las instrucciones de CI/CD en [DEPLOYMENT.md](DEPLOYMENT.md#continuous-deployment-con-github-actions).

## Comandos útiles

### Hacer cambios y desplegar

```bash
git add .
git commit -m "Descripción de los cambios"
git push
```

¡Eso es todo! El push automáticamente iniciará el workflow de deployment.

### Ver status

```bash
git status
```

### Ver historial

```bash
git log --oneline -10
```

## .gitignore

El proyecto ya incluye un `.gitignore` configurado para excluir:
- Build artifacts
- Firebase cache
- Environment variables
- Node modules
- IDE files
