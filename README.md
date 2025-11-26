# Emergency Wear App (SOS Wear)

Una aplicació Flutter per a Wear OS que permet enviar un **SOS** amb la teva ubicació per **SMS o WhatsApp** i activar vibració com alerta.

---

## Característiques

- **Botó SOS gran i central** amb animació de pulsació.
- **Comptador regressiu** de 3 segons abans d’enviar la senyal SOS.
- Envia **SMS i WhatsApp** amb la teva ubicació (Google Maps).
- **Configuració del número d’emergència** des d’una pantalla completa.
- **Compatibilitat amb Wear OS** amb interficie circular.
- **Vibració** per alertar que s’ha enviat el SOS.
- Mostra dades dels sensors de moviment (acceleròmetre i giroscopi) (opcional).

---

## Captures de pantalla

*(Pots afegir aquí captures de l’emulador o dispositiu real)*

---

## Requeriments

- Flutter >= 3.0
- Android Studio amb **emulador Wear OS** o dispositiu físic Wear OS/Android.
- Permisos:
  - `ACCESS_FINE_LOCATION` i `ACCESS_COARSE_LOCATION`
  - `SEND_SMS`
  - `INTERNET` (per WhatsApp)
  - `BODY_SENSORS` (opcional)
  - `VIBRATE`

---

## Instal·lació

1. Clona aquest repositori:

```bash
git clone https://github.com/el-teu-usuari/emergency_wear_app.git
cd emergency_wear_app

