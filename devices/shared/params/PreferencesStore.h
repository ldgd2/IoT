#ifndef PREFERENCES_STORE_H
#define PREFERENCES_STORE_H

/**
 * @file PreferencesStore.h
 * @brief IParamStore para ESP32 usando la API Preferences (NVS).
 *
 * La API Preferences del ESP32 es el método recomendado para almacenamiento
 * no volátil. Usa el sistema NVS (Non-Volatile Storage) de la partición Flash,
 * que soporta wear leveling y es más robusto que EEPROM emulada.
 *
 * El namespace (max 15 chars) se mapea directamente al namespace de Preferences.
 */

#include "IParamStore.h"

#if defined(IS_ESP32)
#include <Preferences.h>
#include <string.h>

class PreferencesStore : public IParamStore {
public:
    bool begin(const char* namespaceName = "colmena") override {
        // readOnly = false → permite escritura
        return _prefs.begin(namespaceName, false);
    }

    uint8_t  getUInt8 (const char* k, uint8_t  dv = 0)    override { return _prefs.getUChar(k,  dv); }
    uint16_t getUInt16(const char* k, uint16_t dv = 0)    override { return _prefs.getUShort(k, dv); }
    uint32_t getUInt32(const char* k, uint32_t dv = 0)    override { return _prefs.getULong(k,  dv); }
    bool     getBool  (const char* k, bool     dv = false) override { return _prefs.getBool(k,   dv); }

    size_t getString(const char* k, char* buf, size_t bufLen,
                     const char* dv = "") override {
        String s = _prefs.getString(k, dv);
        strncpy(buf, s.c_str(), bufLen - 1);
        buf[bufLen - 1] = '\0';
        return strlen(buf);
    }

    bool putUInt8 (const char* k, uint8_t  v) override { return _prefs.putUChar(k,  v) == sizeof(v); }
    bool putUInt16(const char* k, uint16_t v) override { return _prefs.putUShort(k, v) == sizeof(v); }
    bool putUInt32(const char* k, uint32_t v) override { return _prefs.putULong(k,  v) == sizeof(v); }
    bool putBool  (const char* k, bool     v) override { return _prefs.putBool(k,   v) == 1; }
    bool putString(const char* k, const char* v) override {
        return _prefs.putString(k, v) == strlen(v);
    }

    bool remove(const char* k) override { return _prefs.remove(k); }

    void clear() override { _prefs.clear(); }

    void commit() override {
        // Preferences escribe síncronamente al NVS, no necesita commit
    }

private:
    Preferences _prefs;
};

#else
// Plataforma no ESP32: stub que usa EEPROMStore
#include "EEPROMStore.h"
using PreferencesStore = EEPROMStore;
#endif

#endif // PREFERENCES_STORE_H
