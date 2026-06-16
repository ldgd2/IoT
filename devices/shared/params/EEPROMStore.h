#ifndef EEPROM_STORE_H
#define EEPROM_STORE_H

/**
 * @file EEPROMStore.h
 * @brief IParamStore para Arduino AVR y ESP8266.
 *
 * Usa la biblioteca EEPROM estándar de Arduino.
 * En ESP8266 la EEPROM está emulada en Flash (EEPROM.begin(size) requerido).
 * En Arduino AVR es EEPROM real (no requiere begin con tamaño, pero lo acepta).
 *
 * Los parámetros se almacenan serializados con un formato simple:
 * cada clave se hashea a un offset fijo de 64 bytes para evitar buscadores.
 * El espacio total usado es: NUM_KEYS × 64 bytes = max 512 bytes EEPROM.
 */

#include "IParamStore.h"
#include <EEPROM.h>
#include <string.h>

class EEPROMStore : public IParamStore {
public:
    // Tamaño máximo de EEPROM/Flash a reservar
    static const int EEPROM_SIZE = 512;

    bool begin(const char* namespaceName = "colmena") override {
        (void)namespaceName; // No usado en EEPROM simple
#if defined(IS_ESP8266) || defined(IS_ESP32)
        EEPROM.begin(EEPROM_SIZE);
#endif
        return true;
    }

    uint8_t  getUInt8 (const char* key, uint8_t  dv = 0)    override { return _readU8(key,  dv); }
    uint16_t getUInt16(const char* key, uint16_t dv = 0)    override { return _readU16(key, dv); }
    uint32_t getUInt32(const char* key, uint32_t dv = 0)    override { return _readU32(key, dv); }
    bool     getBool  (const char* key, bool     dv = false) override { return _readU8(key, dv ? 1 : 0) != 0; }

    size_t getString(const char* key, char* buf, size_t bufLen,
                     const char* dv = "") override {
        int off = _offset(key);
        // Byte 0 = marker 0xAA, bytes 1..N = string, byte N+1 = 0x00
        if (EEPROM.read(off) != 0xAA) {
            strncpy(buf, dv, bufLen - 1);
            buf[bufLen - 1] = '\0';
            return strlen(buf);
        }
        size_t i = 0;
        for (; i < bufLen - 1; i++) {
            char c = (char)EEPROM.read(off + 1 + i);
            if (c == '\0') break;
            buf[i] = c;
        }
        buf[i] = '\0';
        return i;
    }

    bool putUInt8 (const char* key, uint8_t  v) override { _writeU8(key,  v); return true; }
    bool putUInt16(const char* key, uint16_t v) override { _writeU16(key, v); return true; }
    bool putUInt32(const char* key, uint32_t v) override { _writeU32(key, v); return true; }
    bool putBool  (const char* key, bool     v) override { _writeU8(key, v ? 1 : 0); return true; }

    bool putString(const char* key, const char* value) override {
        int off = _offset(key);
        EEPROM.write(off, 0xAA); // marker
        size_t i = 0;
        while (value[i] && (off + 1 + i) < EEPROM_SIZE - 1) {
            EEPROM.write(off + 1 + i, (uint8_t)value[i]);
            i++;
        }
        EEPROM.write(off + 1 + i, 0x00); // null terminator
        return true;
    }

    bool remove(const char* key) override {
        int off = _offset(key);
        EEPROM.write(off, 0x00); // Borrar marker
        return true;
    }

    void clear() override {
        for (int i = 0; i < EEPROM_SIZE; i++) EEPROM.write(i, 0xFF);
    }

    void commit() override {
#if defined(IS_ESP8266) || defined(IS_ESP32)
        EEPROM.commit();
#endif
        // En Arduino AVR EEPROM.write() es síncrono, no necesita commit
    }

private:
    // Hash simple de la clave a un offset de 64 bytes dentro del espacio EEPROM
    // Esto permite hasta 8 claves distintas en 512 bytes (8 × 64 = 512)
    int _offset(const char* key) {
        uint16_t hash = 0;
        while (*key) hash = (hash * 31 + (uint8_t)*key++) % (EEPROM_SIZE / 64);
        return (int)(hash * 64);
    }

    uint8_t _readU8(const char* key, uint8_t dv) {
        int off = _offset(key);
        if (EEPROM.read(off) != 0xBB) return dv;
        return EEPROM.read(off + 1);
    }
    void _writeU8(const char* key, uint8_t v) {
        int off = _offset(key);
        EEPROM.write(off,     0xBB);
        EEPROM.write(off + 1, v);
    }
    uint16_t _readU16(const char* key, uint16_t dv) {
        int off = _offset(key);
        if (EEPROM.read(off) != 0xCC) return dv;
        return ((uint16_t)EEPROM.read(off + 1) << 8) | EEPROM.read(off + 2);
    }
    void _writeU16(const char* key, uint16_t v) {
        int off = _offset(key);
        EEPROM.write(off,     0xCC);
        EEPROM.write(off + 1, (v >> 8) & 0xFF);
        EEPROM.write(off + 2, v & 0xFF);
    }
    uint32_t _readU32(const char* key, uint32_t dv) {
        int off = _offset(key);
        if (EEPROM.read(off) != 0xDD) return dv;
        return ((uint32_t)EEPROM.read(off+1) << 24) | ((uint32_t)EEPROM.read(off+2) << 16)
             | ((uint32_t)EEPROM.read(off+3) <<  8) |  (uint32_t)EEPROM.read(off+4);
    }
    void _writeU32(const char* key, uint32_t v) {
        int off = _offset(key);
        EEPROM.write(off,     0xDD);
        EEPROM.write(off + 1, (v >> 24) & 0xFF);
        EEPROM.write(off + 2, (v >> 16) & 0xFF);
        EEPROM.write(off + 3, (v >>  8) & 0xFF);
        EEPROM.write(off + 4,  v        & 0xFF);
    }
};

#endif // EEPROM_STORE_H
