# Despliegue de prueba en Render + Neon

Guía para publicar Maykel Repuestos 2 gratis: la app y el backend en
**Render**, la base de datos PostgreSQL en **Neon** (su plan gratuito no
vence, a diferencia del PostgreSQL gratuito de Render, que se borra a los
30 días).

El `Dockerfile` de la raíz compila la app Flutter web y el servidor Dart en
una sola imagen; el servidor sirve la API y la app en la misma dirección.

## 1. Base de datos en Neon

1. Crea una cuenta en <https://neon.com> (no pide tarjeta).
2. Crea un proyecto (nombre: `maykel`). Elige la región disponible más
   cercana a Chile.
3. En **Connect**, copia la *connection string*. Se ve así:
   `postgresql://usuario:clave@ep-xxxx.neon.tech/neondb?sslmode=require`

## 2. Cargar las tablas (una sola vez)

Desde PowerShell, en la carpeta del proyecto (cambia la URL por la tuya,
entre comillas):

```powershell
psql "postgresql://usuario:clave@ep-xxxx.neon.tech/neondb?sslmode=require" -f backend\database\schema.sql
```

> `schema.sql` empieza borrando todas las tablas (`DROP TABLE`). Si lo
> vuelves a ejecutar, se pierden los datos.

Los usuarios de ejemplo de `schema.sql` (`admin`, `daniel`, `vendedor`)
tienen claves que aparecen en el repositorio. En un sitio público hay que
desactivarlos o cambiarles la clave:

```powershell
psql "postgresql://...tu URL..." -c "UPDATE usuarios SET activo = FALSE;"
```

Para entrar al panel se usa entonces `ADMIN_USERS` (paso 3).

## 3. Servicio web en Render

1. Crea una cuenta en <https://render.com> con tu GitHub.
2. **New → Web Service** → elige el repositorio `Kairyu561/Maykel_Render`.
3. Configuración:
   - **Language / Runtime:** Docker (lo detecta solo por el `Dockerfile`).
   - **Branch:** `main`
   - **Instance Type:** Free
4. **Environment Variables:**

   | Variable | Valor |
   |---|---|
   | `DATABASE_URL` | La URL de Neon del paso 1 |
   | `ADMIN_USERS` | `admin:UnaClaveSegura` (usuario y clave del panel) |
   | `SYNC_API_TOKEN` | Opcional: un texto largo y secreto, solo si se usará la sincronización |

5. En **Advanced → Health Check Path** escribe `/api/health`.
6. **Create Web Service**.

La primera compilación tarda varios minutos (compila Flutter). En los
**Logs** debe aparecer:

```
✅ Conectado exitosamente a PostgreSQL (neondb en ep-xxxx.neon.tech:5432)
🚀 Servidor Backend Unificado Maykel Repuestos 2 (PostgreSQL) corriendo en http://localhost:10000
```

Luego abre la dirección que muestra Render (`https://maykel-render.onrender.com`
o similar). Cada `push` a `main` vuelve a desplegar solo.

## Límites del plan gratuito

- El sitio se duerme tras 15 minutos sin visitas y tarda cerca de 1 minuto
  en despertar.
- 750 horas al mes por cuenta (alcanza para un servicio todo el mes).
- Neon también suspende la base tras unos minutos sin uso; el servidor
  reconecta solo.

## Problemas conocidos de esta versión

- Las fechas de reservas se muestran en hora UTC (3 horas adelante de
  Chile), porque la base de datos guarda `TIMESTAMP` sin zona horaria.
- No funcionan "Registrar venta" ni editar o borrar roles y usuarios (faltan
  esas rutas en el backend).
- Los precios no se pueden cargar desde el panel.

## Si algo falla

- **La compilación falla en `flutter pub get`:** la imagen de Flutter es más
  antigua de lo que pide `app/pubspec.lock`. Avisar para fijar la versión.
- **`Error al conectar a PostgreSQL`:** revisar `DATABASE_URL` en Render
  (copiarla de nuevo desde Neon, sin espacios).
- **401 al entrar al panel:** revisar `ADMIN_USERS` (formato `usuario:clave`).
