# Marketcatia — App Flutter (iOS + Android)

Clon nativo de la web [`marketcatia`](../marketcatia) para iOS y Android.

## Requisitos

- Flutter 3.44+
- Xcode + CocoaPods (iOS)
- Android Studio / SDK 23+
- Apps Android/iOS registradas en Firebase `marketcatia-c91ae` (recomendado: `google-services.json` y `GoogleService-Info.plist`)

## Ejecutar

```bash
cd app_marketcatia
flutter pub get
flutter run
```

## Rutas

| Ruta | Pantalla |
|------|----------|
| `/` | Catálogo (categorías, ofertas, más vendidos) |
| `/login` | Login / registro |
| `/recovery-password` | Recuperar contraseña |
| `/account` | Cuenta + direcciones |
| `/cart` | Checkout 3 pasos |
| `/temp-order/:id` | Pedido temporal (chatbot) |
| `/order-view-v2/:id` | Detalle de pedido |
| `/qr` | QR del catálogo |
| `/campana/banner/:id` | Campaña banner |
| `/campana/ofertas` | Ofertas del día |

Deep links: esquema `marketcatia://` (también HTTPS host `marketcatia.com`).

## Backend

- API: `https://marketcatia-api.up.railway.app`
- Firebase: Auth, Firestore, Storage
- Maps: Google Maps SDK

## Estructura

```
lib/
  config/     API + Firebase options
  theme/      tokens CSS → AppColors
  providers/  AppProvider (estado global)
  services/   API REST + Firebase
  screens/    pantallas
  widgets/    Header, Nav, catálogo, Emily, modal pago
```
