#ifndef IPARAMSTORE_H
#define IPARAMSTORE_H

/**
 * @file IParamStore.h
 * @brief Interfaz abstracta para persistencia de parámetros — shared/.
 *
 * Abstrae el almacenamiento no-volátil de parámetros de configuración
 * independientemente del hardware de memoria del microcontrolador.
 *
 * Implementaciones concretas seleccionadas en compile-time mediante
 * el alias `ParamStore` en main.cpp (o en un header de selección):
 *
 *   IS_ESP32   → PreferencesStore (NVS)
 *   IS_RP2040  → FlashStore (LittleFS)
 *   default    → EEPROMStore (EEPROM / emulada en Flash)
 *
 * Compatibilidad: ESP32 · ESP8266 · RP2040 · Raspberry Pi Pico · Arduino
 */

#include <stdint.h>
#include <stddef.h>

class IParamStore {
public:
    virtual ~IParamStore() {}

    /**
     * @brief Inicializa el sistema de almacenamiento.
     * @param namespaceName Espacio de nombres para agrupar parámetros
     *                      (usado en NVS/Preferences, ignorado en EEPROM simple)
     * @return true si la inicialización fue exitosa
     */
    virtual bool begin(const char* namespaceName = "colmena") = 0;

    // ── Lectura ──────────────────────────────────────────────────────────────
    virtual uint8_t  getUInt8 (const char* key, uint8_t  defaultValue = 0)    = 0;
    virtual uint16_t getUInt16(const char* key, uint16_t defaultValue = 0)    = 0;
    virtual uint32_t getUInt32(const char* key, uint32_t defaultValue = 0)    = 0;
    virtual bool     getBool  (const char* key, bool     defaultValue = false) = 0;

    /**
     * @brief Lee una cadena de texto del almacenamiento.
     * @param key          Clave del parámetro
     * @param buf          Buffer de destino (null-terminated)
     * @param bufLen       Tamaño del buffer
     * @param defaultValue Valor por defecto si la clave no existe
     * @return Número de caracteres leídos (sin incluir el '\0')
     */
    virtual size_t getString(const char* key, char* buf, size_t bufLen,
                             const char* defaultValue = "") = 0;

    // ── Escritura ─────────────────────────────────────────────────────────────
    virtual bool putUInt8 (const char* key, uint8_t  value) = 0;
    virtual bool putUInt16(const char* key, uint16_t value) = 0;
    virtual bool putUInt32(const char* key, uint32_t value) = 0;
    virtual bool putBool  (const char* key, bool     value) = 0;
    virtual bool putString(const char* key, const char* value) = 0;

    // ── Gestión ───────────────────────────────────────────────────────────────
    /**
     * @brief Elimina una clave específica del almacenamiento.
     * @return true si la clave existía y fue eliminada
     */
    virtual bool remove(const char* key) = 0;

    /**
     * @brief Borra todos los parámetros del namespace actual (factory reset).
     */
    virtual void clear() = 0;

    /**
     * @brief Confirma los cambios al medio físico.
     * En EEPROM (ESP8266): llama EEPROM.commit().
     * En LittleFS y NVS: escritura síncrona, commit() es no-op.
     */
    virtual void commit() = 0;
};

#endif // IPARAMSTORE_H
