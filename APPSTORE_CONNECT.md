# Subida iOS a App Store Connect

## Datos configurados

- **Bundle ID:** `com.marketcatia.appMarketcatia`
- **Team ID / Provider ID:** `FAKA27MKTF`
- **Key ID:** `9XBVL3MN32`
- **Archivo .p8:** `private_keys/AuthKey_9XBVL3MN32.p8`
- **IPA generado:** `build/ios/ipa/app_marketcatia.ipa`

## Datos que faltan

- **Issuer ID:** Reemplaza `<ISSUER_ID>` en el comando de abajo. Lo encuentras en App Store Connect → Users and Access → Integrations → App Store Connect API.

## Comando de subida

```bash
xcrun altool --upload-app --type ios \
  -f build/ios/ipa/app_marketcatia.ipa \
  --apiKey 9XBVL3MN32 \
  --apiIssuer <ISSUER_ID>
```

La clave privada `.p8` ya está copiada en `~/.appstoreconnect/private_keys/`, que es donde `altool` la busca por defecto.
