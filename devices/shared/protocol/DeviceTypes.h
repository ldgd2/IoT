#ifndef DEVICE_TYPES_H
#define DEVICE_TYPES_H

/**
 * @file DeviceTypes.h
 * @brief Identificadores compactos de dispositivos y capacidades — shared/protocol/
 *
 * Sistema de identificación en 2 bytes por dispositivo:
 *
 *   Byte 1 → DevType   (uint8_t) — QUÉ es el dispositivo
 *   Byte 2 → Features  (uint8_t) — QUÉ puede hacer (bitmask)
 *
 * Con 1 solo byte para el tipo soportamos 256 tipos de dispositivos.
 * El byte se divide en nibbles para agrupar por categoría:
 *
 *   Bits [7:4] = Categoría   (16 categorías posibles)
 *   Bits [3:0] = Sub-tipo    (16 variantes por categoría)
 *
 * El gateway transmite estos valores al backend Python, que los traduce
 * a lenguaje natural usando la tabla de device_types.py (mismo archivo en Python).
 *
 * ─── Encoding ejemplo ────────────────────────────────────────────────────────
 *
 *  Dispositivo: Enchufe inteligente con medición de energía
 *    deviceType = DEV_PLUG          = 0x01
 *    features   = FEAT_RELAY
 *               | FEAT_ENERGY       = 0x01 | 0x20 = 0x21
 *
 *  Dispositivo: Tira LED regulable
 *    deviceType = DEV_LIGHT         = 0x02
 *    features   = FEAT_RELAY
 *               | FEAT_DIMMER       = 0x01 | 0x02 = 0x03
 *
 *  Dispositivo: Sensor multiparámetro
 *    deviceType = DEV_SENSOR        = 0x10
 *    features   = FEAT_TEMP
 *               | FEAT_HUMIDITY
 *               | FEAT_MOTION       = 0x04 | 0x08 | 0x10 = 0x1C
 *
 * ─── Guía para agregar un nuevo tipo ────────────────────────────────────────
 *   1. Agregar DEV_XXXX aquí con el siguiente nibble disponible
 *   2. Agregar la entrada en device_types.py (Python backend)
 *   3. El resto del protocolo NO necesita cambios
 *
 * Compatibilidad: ESP32 · ESP8266 · RP2040 · Raspberry Pi Pico · Arduino
 */

#include <stdint.h>

// ─────────────────────────────────────────────────────────────────────────────
// Tipos de dispositivo — DevType (uint8_t)
// Byte completo: 1 valor = 1 tipo único. Categorías por nibble alto.
// ─────────────────────────────────────────────────────────────────────────────

// ── Categoría 0x0X — Control de carga (switching) ───────────────────────────
#define DEV_UNKNOWN       0x00   // Dispositivo desconocido / sin clasificar
#define DEV_PLUG          0x01   // Enchufe inteligente
#define DEV_LIGHT         0x02   // Luz (bombillo, tira LED, panel)
#define DEV_SWITCH        0x03   // Interruptor de pared
#define DEV_DIMMER        0x04   // Dimmer / atenuador (PWM)
#define DEV_FAN           0x05   // Ventilador
#define DEV_CURTAIN       0x06   // Persiana / cortina / toldo
#define DEV_VALVE         0x07   // Válvula (agua, gas)
#define DEV_PUMP          0x08   // Bomba (agua, riego)
#define DEV_STRIP         0x09   // Tira LED RGB/RGBW

// ── Categoría 0x1X — Sensado ──────────────────────────────────────────────────
#define DEV_SENSOR        0x10   // Sensor genérico
#define DEV_SENSOR_TEMP   0x11   // Sensor de temperatura
#define DEV_SENSOR_PIR    0x12   // Sensor de movimiento (PIR)
#define DEV_SENSOR_DOOR   0x13   // Sensor de puerta/ventana
#define DEV_SENSOR_SMOKE  0x14   // Detector de humo
#define DEV_SENSOR_FLOOD  0x15   // Sensor de inundación
#define DEV_SENSOR_GAS    0x16   // Detector de gas
#define DEV_SENSOR_LUX    0x17   // Sensor de luz ambiente
#define DEV_SENSOR_SOIL   0x18   // Sensor de humedad de suelo (riego)
#define DEV_SENSOR_POWER  0x19   // Medidor de energía (kWh)
#define DEV_SENSOR_BUTTON 0x1A   // Botón/pulsador inalámbrico

// ── Categoría 0x2X — Clima / HVAC ────────────────────────────────────────────
#define DEV_THERMOSTAT    0x20   // Termostato
#define DEV_AC            0x21   // Aire acondicionado
#define DEV_HEATER        0x22   // Calefactor
#define DEV_HUMIDIFIER    0x23   // Humidificador

// ── Categoría 0x3X — Seguridad ───────────────────────────────────────────────
#define DEV_LOCK          0x30   // Cerradura inteligente
#define DEV_CAMERA        0x31   // Cámara (gateway de cámara)
#define DEV_SIREN         0x32   // Sirena / alarma sonora
#define DEV_KEYPAD        0x33   // Teclado de acceso

// ── Categoría 0x4X — Audio/Video ─────────────────────────────────────────────
#define DEV_SPEAKER       0x40   // Altavoz inteligente
#define DEV_DISPLAY_NODE  0x41   // Nodo con pantalla (info panel)

// ── Categoría 0xFX — Sistema ──────────────────────────────────────────────────
#define DEV_GATEWAY       0xF0   // Translator / Gateway (nodo master)
#define DEV_REPEATER      0xF1   // Repetidor RF
#define DEV_ALL           0xFF   // Broadcast → aplica a todos los tipos


// ─────────────────────────────────────────────────────────────────────────────
// Feature Flags — Capacidades del dispositivo (uint8_t bitmask)
// Se combinan con OR: features = FEAT_RELAY | FEAT_ENERGY
// ─────────────────────────────────────────────────────────────────────────────

#define FEAT_RELAY        0x01   // Bit 0 — Tiene actuador ON/OFF (relay/transistor)
#define FEAT_DIMMER       0x02   // Bit 1 — Control de brillo/velocidad (PWM)
#define FEAT_TEMP         0x04   // Bit 2 — Sensor de temperatura
#define FEAT_HUMIDITY     0x08   // Bit 3 — Sensor de humedad
#define FEAT_MOTION       0x10   // Bit 4 — Sensor de movimiento (PIR)
#define FEAT_ENERGY       0x20   // Bit 5 — Medición de consumo energético
#define FEAT_DISPLAY      0x40   // Bit 6 — Tiene pantalla local
#define FEAT_BATTERY      0x80   // Bit 7 — Alimentado por batería


// ─────────────────────────────────────────────────────────────────────────────
// Macros de utilidad
// ─────────────────────────────────────────────────────────────────────────────

/** @brief Retorna la categoría de un tipo de dispositivo (nibble alto). */
#define DEV_CATEGORY(type)    ((uint8_t)((type) >> 4))

/** @brief Retorna el sub-tipo de un dispositivo (nibble bajo). */
#define DEV_SUBTYPE(type)     ((uint8_t)((type) & 0x0F))

/** @brief Verifica si un dispositivo tiene una feature específica. */
#define DEV_HAS_FEAT(features, flag)  (((features) & (flag)) != 0)

/** @brief Verifica si el tipo es un switching device (categoría 0x0X). */
#define DEV_IS_SWITCH_CAT(type)   (DEV_CATEGORY(type) == 0x00 && (type) != DEV_UNKNOWN)

/** @brief Verifica si el tipo es un sensor (categoría 0x1X). */
#define DEV_IS_SENSOR_CAT(type)   (DEV_CATEGORY(type) == 0x01)

/** @brief Verifica si el tipo es del sistema (categoría 0xFX). */
#define DEV_IS_SYSTEM(type)       (DEV_CATEGORY(type) == 0x0F)


// ─────────────────────────────────────────────────────────────────────────────
// Mantener retrocompatibilidad con los #define viejos de Protocol.h
// (para no romper código existente mientras se migra)
// ─────────────────────────────────────────────────────────────────────────────
#define DEV_TYPE_GATEWAY   DEV_GATEWAY
#define DEV_TYPE_LIGHT     DEV_LIGHT
#define DEV_TYPE_SENSOR    DEV_SENSOR

#define FEATURE_RELAY      FEAT_RELAY
#define FEATURE_BRIGHTNESS FEAT_DIMMER
#define FEATURE_TEMP       FEAT_TEMP
#define FEATURE_HUMIDITY   FEAT_HUMIDITY
#define FEATURE_MOTION     FEAT_MOTION
#define FEATURE_DOOR       FEAT_MOTION   // Door sensor usa el mismo bit que motion

#endif // DEVICE_TYPES_H
