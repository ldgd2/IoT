#ifndef PIN_CONFIG_H
#define PIN_CONFIG_H

/**
 * @file PinConfig.h — lights
 * @brief Configuración de pines de hardware del nodo de iluminación.
 *
 * Solo asignaciones de GPIO. NO contiene lógica, structs ni protocolo.
 *
 * ── Identidad del nodo ───────────────────────────────────────────────────────
 * NODE_ID y NODE_NAME pueden ser overrideados desde platformio.ini:
 *   build_flags = -D NODE_ID=2 -D NODE_NAME='"Luz-02"'
 *
 * ── RelayBank ────────────────────────────────────────────────────────────────
 * Declarar tantos RELAY_PIN_x como relays tenga el dispositivo.
 * Ajustar RELAY_COUNT al número real de relays.
 * RELAY_PINS es el array de pines que RelayBank recibe en init().
 * RELAY_ACTIVE_LOW=true para módulos de relay que usan lógica invertida.
 *
 * Plataformas: IS_RP2040 · IS_ESP8266 · IS_ESP32 · IS_ARDUINO (default)
 */

// ─── Identidad del nodo ───────────────────────────────────────────────────────
// NODE_ID y NODE_NAME pueden ser overrideados desde platformio.ini:
//   build_flags = -D NODE_ID=2 -D NODE_NAME='"Luz-02"'
// NODE_DEVICE_TYPE y NODE_FEATURES usan los valores de DeviceTypes.h
// (incluido automáticamente vía Protocol.h → DeviceTypes.h)

#ifndef NODE_ID
  #define NODE_ID           1           // Override con -D NODE_ID=N
#endif
#ifndef NODE_NAME
  #define NODE_NAME         "Luz-01"   // Override con -D NODE_NAME='"Luz-02"'
#endif
#ifndef NODE_DEVICE_TYPE
  #define NODE_DEVICE_TYPE  DEV_LIGHT   // 0x02 — ver DeviceTypes.h
#endif
#ifndef NODE_FEATURES
  #define NODE_FEATURES     FEAT_RELAY  // 0x01 — relay ON/OFF
#endif


// ─── Radio nRF24L01 (SPI) ─────────────────────────────────────────────────────
#if defined(IS_RP2040)
    // Raspberry Pi Pico / YD-RP2040 — SPI0: SCK=18, MOSI=19, MISO=16
    #define CE_PIN    14
    #define CSN_PIN   15
    #define IRQ_PIN   13

#elif defined(IS_ESP8266)
    // NodeMCU v2 / ESP8266 — SPI: SCK=D5, MOSI=D7, MISO=D6
    #define CE_PIN    D4    // GPIO2
    #define CSN_PIN   D8    // GPIO15
    #define IRQ_PIN   D2    // GPIO4

#elif defined(IS_ESP32)
    // ESP32 DevKit — SPI: SCK=18, MOSI=23, MISO=19
    #define CE_PIN    4
    #define CSN_PIN   5
    #define IRQ_PIN   2

#else
    // Arduino Uno / Nano / Mega — SPI: SCK=13, MOSI=11, MISO=12
    #define CE_PIN    7
    #define CSN_PIN   8
    #define IRQ_PIN   2
#endif

// ─── Relays (RelayBank) ───────────────────────────────────────────────────────
// Ajustar según el hardware específico del nodo.
// Para agregar más relays: añadir RELAY_PIN_1, _2... y aumentar RELAY_COUNT.

#if defined(IS_RP2040)
    #define RELAY_PIN_0      5
    #define RELAY_PIN_1      6
    #define RELAY_PIN_2      7
    #define RELAY_PIN_3      8
    #define RELAY_COUNT      4
    #define RELAY_ACTIVE_LOW true

#elif defined(IS_ESP8266)
    #define RELAY_PIN_0      5    // D1 = GPIO5
    #define RELAY_COUNT      1
    #define RELAY_ACTIVE_LOW true

#elif defined(IS_ESP32)
    #define RELAY_PIN_0      25
    // #define RELAY_PIN_1    26
    // #define RELAY_PIN_2    27
    // #define RELAY_PIN_3    14
    #define RELAY_COUNT      1
    #define RELAY_ACTIVE_LOW true

#else
    // Arduino
    #define RELAY_PIN_0      5
    #define RELAY_COUNT      1
    #define RELAY_ACTIVE_LOW true
#endif

// ─── Botón de Vinculación (pair / táctil) ──────────────────────────────────
// Botón que al tocarlo re-anuncia el nodo al master (CMD_DISCOVER).
// Usar con colmena.initPairButton(PAIR_BUTTON_PIN, PAIR_BUTTON_ACTIVE_LOW) en setup()
// y colmena.tickPairButton(NODE_NAME) en loop().
// Comentar #define PAIR_BUTTON_PIN si el dispositivo no tiene botón físico.

// Lógica de activación:
// true  = Pulsador mecánico tradicional a GND o botón integrado del YD-RP2040 (activo en LOW con pull-up)
// false = Botón Táctil (TTP223 / capacitivo) o sensor activo en HIGH (3.3V al tocar)
#define PAIR_BUTTON_ACTIVE_LOW false

#if defined(IS_RP2040)
    #define PAIR_BUTTON_PIN  3        // GPIO2 — conectar OUT/SIG del botón táctil aquí

#elif defined(IS_ESP8266)
    #define PAIR_BUTTON_PIN  0        // D3 = GPIO0 (botón FLASH o táctil)

#elif defined(IS_ESP32)
    #define PAIR_BUTTON_PIN  0        // GPIO0 (botón BOOT o táctil)

#else
    #define PAIR_BUTTON_PIN  3        // Arduino: pin 3 (INT1)
#endif

// ─── Array de pines para RelayBank::init() ───────────────────────────────────
// Se construye automáticamente desde los RELAY_PIN_x definidos arriba.
// PinConfig.h es el ÚNICO lugar donde se edita la lista de pines de relay.

#if   RELAY_COUNT == 1
    static const uint8_t RELAY_PINS[] = { RELAY_PIN_0 };
#elif RELAY_COUNT == 2
    static const uint8_t RELAY_PINS[] = { RELAY_PIN_0, RELAY_PIN_1 };
#elif RELAY_COUNT == 3
    static const uint8_t RELAY_PINS[] = { RELAY_PIN_0, RELAY_PIN_1, RELAY_PIN_2 };
#elif RELAY_COUNT == 4
    static const uint8_t RELAY_PINS[] = { RELAY_PIN_0, RELAY_PIN_1, RELAY_PIN_2, RELAY_PIN_3 };
#elif RELAY_COUNT == 8
    static const uint8_t RELAY_PINS[] = {
        RELAY_PIN_0, RELAY_PIN_1, RELAY_PIN_2, RELAY_PIN_3,
        RELAY_PIN_4, RELAY_PIN_5, RELAY_PIN_6, RELAY_PIN_7
    };
#elif RELAY_COUNT == 16
    static const uint8_t RELAY_PINS[] = {
        RELAY_PIN_0,  RELAY_PIN_1,  RELAY_PIN_2,  RELAY_PIN_3,
        RELAY_PIN_4,  RELAY_PIN_5,  RELAY_PIN_6,  RELAY_PIN_7,
        RELAY_PIN_8,  RELAY_PIN_9,  RELAY_PIN_10, RELAY_PIN_11,
        RELAY_PIN_12, RELAY_PIN_13, RELAY_PIN_14, RELAY_PIN_15
    };
#else
    #error "RELAY_COUNT no soportado. Valores validos: 1, 2, 3, 4, 8, 16"
#endif

#endif // PIN_CONFIG_H
