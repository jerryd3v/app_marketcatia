# Marketcatia — App Flutter (iOS + Android)

App nativa de la tienda Marketcatia.

| | |
|--|--|
| API | `https://marketcatia-api.up.railway.app` |
| Firebase | `marketcatia-c91ae` |
| iOS | `com.marketcatia.appMarketcatia` |
| Android | `com.marketcatia.app_marketcatia` |

---

## Copiar y pegar en la terminal

### Abrir el emulador iPhone

```bash
cd /Users/macbook/Documents/repositorios/app_marketcatia && xcrun simctl boot "iPhone 17 Pro" 2>/dev/null; open -a Simulator
```

### Correr la app

```bash
cd /Users/macbook/Documents/repositorios/app_marketcatia && flutter run -d "iPhone 17 Pro"
```

### Emulador + app (todo junto)

```bash
cd /Users/macbook/Documents/repositorios/app_marketcatia && xcrun simctl boot "iPhone 17 Pro" 2>/dev/null; open -a Simulator && flutter run -d "iPhone 17 Pro"
```

### iPad 11"

```bash
cd /Users/macbook/Documents/repositorios/app_marketcatia && xcrun simctl boot "iPad Pro 11-inch (M5)" 2>/dev/null; open -a Simulator && flutter run -d "iPad Pro 11-inch (M5)"
```

### Cerrar emulador

```bash
killall Simulator; xcrun simctl shutdown all
```

### Build Android (AAB Play Store)

```bash
cd /Users/macbook/Documents/repositorios/app_marketcatia && ./tool/build_play.sh
```

Archivo: `build/app/outputs/bundle/release/app-release.aab`

### Build iOS (abrir Xcode)

```bash
cd /Users/macbook/Documents/repositorios/app_marketcatia && open ios/Runner.xcworkspace
```

Luego en Xcode: **Any iOS Device (arm64)** → **Product → Archive** → Upload.

### Con la app corriendo

| Tecla | Acción |
|-------|--------|
| `r` | Hot reload |
| `R` | Hot restart |
| `q` | Salir |

### Si algo falla

```bash
cd /Users/macbook/Documents/repositorios/app_marketcatia && flutter clean && flutter pub get
```

```bash
cd /Users/macbook/Documents/repositorios/app_marketcatia && flutter devices
```

---

## Scripts (opcional)

Si prefieres scripts cortos:

```bash
cd /Users/macbook/Documents/repositorios/app_marketcatia
./tool/start_simulator.sh
./tool/run_app.sh
```

| Script | Qué hace |
|--------|----------|
| `tool/start_simulator.sh` | Abre Simulator |
| `tool/run_app.sh` | `flutter run` |
| `tool/build_play.sh` | AAB Play Store |

---

## Rutas

| Ruta | Pantalla |
|------|----------|
| `/` | Catálogo |
| `/login` | Login / registro |
| `/recovery-password` | Recuperar contraseña |
| `/account` | Cuenta (Eliminar cuenta) |
| `/cart` | Checkout |
| `/temp-order/:id` | Pedido temporal |
| `/order-view-v2/:id` | Detalle pedido |
| `/qr` | QR catálogo |
| `/campana/banner/:id` | Campaña |
| `/campana/ofertas` | Ofertas del día |

---

## Estructura

```
lib/
  config/     API + Firebase
  theme/
  providers/
  services/
  screens/
  widgets/
```

Firebase: `android/app/google-services.json` · `ios/Runner/GoogleService-Info.plist`
