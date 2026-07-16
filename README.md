# Marketcatia — App Flutter (iOS + Android)

Clon nativo de la web Marketcatia. Solo **iOS** y **Android**.

---

## 1. Primera vez (instalar dependencias)

Abre la terminal en la carpeta del proyecto:

```bash
cd /Users/macbook/Documents/repositorios/app_marketcatia
flutter pub get
```

---

## 2. Abrir un emulador / simulador

La app **no corre** en macOS ni Chrome. Necesitas iPhone Simulator o emulador Android.

### Opción A — iOS (recomendado en Mac)

```bash
# Abrir el Simulator de Apple
open -a Simulator

# (si no arranca un iPhone solo)
xcrun simctl boot "iPhone 17 Pro"
open -a Simulator
```

### Opción B — Android

```bash
# Ver emuladores disponibles
flutter emulators

# Arrancar el AVD (si existe Pixel_8_API_35)
flutter emulators --launch Pixel_8_API_35
```

O desde **Android Studio** → Device Manager → ▶️ Play.

### Ver qué dispositivos detecta Flutter

```bash
flutter devices
```

Debes ver algo como `iPhone 17 Pro` o un emulador Android.  
Si solo ves `macOS` y `Chrome`, **aún no hay emulador listo**.

---

## 3. Correr la app

Con el emulador ya abierto:

```bash
cd /Users/macbook/Documents/repositorios/app_marketcatia
flutter run
```

Si hay varios dispositivos, elige el ID que te muestra `flutter devices`:

```bash
# Ejemplo iOS
flutter run -d 59B85589-9D39-4CA8-99F7-40C73DD0B8F8

# O por nombre
flutter run -d "iPhone 17 Pro"
```

La **primera** vez tarda (compila). Después es más rápido.

---

## 4. Mientras la app está corriendo (terminal de `flutter run`)

No cierres esa terminal. Usa estas teclas:

| Tecla | Qué hace |
|-------|----------|
| `r` | **Hot reload** — aplica cambios de UI rápido (casi al instante) |
| `R` | **Hot restart** — reinicia la app por completo (mantiene el proceso) |
| `q` | **Quit** — cierra la app y termina `flutter run` |
| `h` | Lista todos los comandos |
| `d` | Detach — deja la app abierta pero suelta la terminal |

### Flujo típico al editar código

1. Tienes `flutter run` activo.
2. Cambias un archivo en `lib/`.
3. Guardas.
4. En la terminal pulsas **`r`** (reload en caliente).

Si el cambio no se ve (por ejemplo auth, `main.dart`, rutas), pulsa **`R`**.

---

## 5. Comandos útiles del día a día

```bash
# Limpiar build si algo raro pasa
flutter clean
flutter pub get

# Analizar errores de código
flutter analyze lib

# Ver emuladores / dispositivos
flutter devices
flutter emulators

# Correr en un dispositivo concreto
flutter run -d <device_id>
```

---

## 6. Firebase (archivos ya en el repo)

| Archivo | Ruta |
|---------|------|
| Android | `android/app/google-services.json` |
| iOS | `ios/Runner/GoogleService-Info.plist` |

Project ID: `marketcatia-c91ae`

---

## 7. Rutas de la app

| Ruta | Pantalla |
|------|----------|
| `/` | Catálogo |
| `/login` | Login / registro |
| `/recovery-password` | Recuperar contraseña |
| `/account` | Cuenta + direcciones |
| `/cart` | Checkout 3 pasos |
| `/temp-order/:id` | Pedido temporal |
| `/order-view-v2/:id` | Detalle pedido |
| `/qr` | QR catálogo |
| `/campana/banner/:id` | Campaña |
| `/campana/ofertas` | Ofertas del día |

---

## 8. Backend

- API: `https://marketcatia-api.up.railway.app`
- Firebase: Auth, Firestore, Storage
- Maps: Google Maps SDK

---

## 9. Estructura del código

```
lib/
  config/     API + Firebase options
  theme/      colores / tema
  providers/  estado global
  services/   API REST + Firebase
  screens/    pantallas
  widgets/    Header, Nav, catálogo, etc.
```

---

## Problemas frecuentes

**`No supported devices connected`**  
→ Abre el Simulator / emulador primero, luego `flutter devices`, luego `flutter run`.

**Pantalla negra / se cierra sola**  
→ Revisa que existan `google-services.json` y `GoogleService-Info.plist`. Luego:

```bash
flutter clean && flutter pub get && flutter run
```

**Hot reload no aplica el cambio**  
→ Pulsa `R` (restart) o vuelve a ejecutar `flutter run`.
