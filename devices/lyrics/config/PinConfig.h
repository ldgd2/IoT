#ifndef PIN_CONFIG_H
#define PIN_CONFIG_H

/**
 * @file PinConfig.h (lyrics)
 * @brief Configuración de pines para el dispositivo de prueba de líricas musicales.
 */

#ifndef NODE_ID
  #define NODE_ID           99           // ID de prueba
#endif
#ifndef NODE_NAME
  #define NODE_NAME         "Lyrics-01"
#endif
#ifndef NODE_DEVICE_TYPE
  #define NODE_DEVICE_TYPE  0x05         // Tipo custom / test
#endif
#ifndef NODE_FEATURES
  #define NODE_FEATURES     0x00         // Sin actuadores físicos
#endif

// ─────────────────────────────────────────────────────────────────────────────
// Pines del Radio nRF24L01 (SPI)
// ─────────────────────────────────────────────────────────────────────────────
#if defined(IS_RP2040)
    #define CE_PIN   14
    #define CSN_PIN  15
    #define IRQ_PIN  13
#elif defined(IS_ESP8266)
    #define CE_PIN   D4
    #define CSN_PIN  D8
    #define IRQ_PIN  D2
#elif defined(IS_ESP32)
    #define CE_PIN   4
    #define CSN_PIN  5
    #define IRQ_PIN  2
#else
    #define CE_PIN   7
    #define CSN_PIN  8
    #define IRQ_PIN  2
#endif

// ─────────────────────────────────────────────────────────────────────────────
// Pines de la Pantalla OLED SSD1306 (I2C)
// ─────────────────────────────────────────────────────────────────────────────
#if defined(IS_RP2040)
    #define OLED_SDA  4
    #define OLED_SCL  5
#elif defined(IS_ESP32)
    #define OLED_SDA  21
    #define OLED_SCL  22
#endif

#define OLED_I2C_ADDR  0x3C
#define OLED_WIDTH   128
#define OLED_HEIGHT   64

#endif // PIN_CONFIG_H
