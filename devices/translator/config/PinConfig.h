#ifndef PIN_CONFIG_H
#define PIN_CONFIG_H

/**
 * @file PinConfig.h (translator)
 * @brief Configuración de pines de hardware — Solo asignaciones de GPIO.
 *
 * El translator (gateway) conecta: radio nRF24L01 (SPI) + pantalla OLED (I2C).
 * En RP2040 también gestiona USB HID (nativo, sin pines extra).
 *
 * Selección por plataforma en compile-time vía build_flags en platformio.ini:
 *   -D IS_RP2040     → Raspberry Pi Pico / YD-RP2040
 *   -D IS_ESP8266    → NodeMCU v2 / ESP8266
 *   -D IS_ESP32      → ESP32 DevKit
 *   -D IS_ARDUINO    → Arduino Uno / Nano / Mega
 */

// ─────────────────────────────────────────────────────────────────────────────
// Pines del Radio nRF24L01 (SPI)
// ─────────────────────────────────────────────────────────────────────────────

#if defined(IS_RP2040)
    // Raspberry Pi Pico / YD-RP2040
    // SPI0: SCK=18, MOSI=19, MISO=16 (hardware SPI)
    #define CE_PIN   14
    #define CSN_PIN  15
    #define IRQ_PIN  13

#elif defined(IS_ESP8266)
    // NodeMCU v2 / ESP8266
    // SPI: SCK=D5(14), MOSI=D7(13), MISO=D6(12)
    #define CE_PIN   D4   // GPIO2
    #define CSN_PIN  D8   // GPIO15
    #define IRQ_PIN  D2   // GPIO4

#elif defined(IS_ESP32)
    // ESP32 DevKit
    // SPI: SCK=18, MOSI=23, MISO=19
    #define CE_PIN   4
    #define CSN_PIN  5
    #define IRQ_PIN  2

#else
    // Arduino Uno / Nano / Mega (default)
    #define CE_PIN   7
    #define CSN_PIN  8
    #define IRQ_PIN  2
#endif

// ─────────────────────────────────────────────────────────────────────────────
// Pines de la Pantalla OLED SSD1306 (I2C)
// ─────────────────────────────────────────────────────────────────────────────
// La mayoría de plataformas usa los pines I2C por defecto del hardware.
// Solo se definen pines customizados si la placa lo requiere.

#if defined(IS_RP2040)
    // I2C0: SDA=4, SCL=5 (default en earlephilhower core)
    #define OLED_SDA  4
    #define OLED_SCL  5

#elif defined(IS_ESP32)
    // Pines I2C configurables en ESP32
    #define OLED_SDA  21
    #define OLED_SCL  22

#else
    // ESP8266 / Arduino: pines I2C por defecto del hardware
    // No se definen, Wire usa los defaults (A4/A5 en Arduino, D2/D1 en ESP8266)
#endif

// Dirección I2C del OLED (típicamente 0x3C o 0x3D)
#define OLED_I2C_ADDR  0x3C

// Dimensiones del display
#define OLED_WIDTH   128
#define OLED_HEIGHT   64

#endif // PIN_CONFIG_H
