#ifndef FLASH_STORE_H
#define FLASH_STORE_H

/**
 * @file FlashStore.h
 * @brief IParamStore para Raspberry Pi Pico / YD-RP2040.
 *
 * Usa LittleFS (sistema de archivos en Flash) disponible en el core
 * earlephilhower para RP2040. Los parámetros se guardan como archivos
 * individuales en un directorio con el nombre del namespace.
 *
 * Requiere en platformio.ini:
 *   board_build.filesystem = littlefs
 * Y la librería: earlephilhower/LittleFS (incluida en el core RP2040)
 */

#include "IParamStore.h"

#if defined(IS_RP2040)
#include <LittleFS.h>
#include <string.h>
#include <stdio.h>

class FlashStore : public IParamStore {
public:
    FlashStore() { _ns[0] = '\0'; }

    bool begin(const char* namespaceName = "colmena") override {
        strncpy(_ns, namespaceName, sizeof(_ns) - 1);
        _ns[sizeof(_ns) - 1] = '\0';

        if (!LittleFS.begin()) {
            // Formatea si el sistema de archivos no existe
            LittleFS.format();
            if (!LittleFS.begin()) return false;
        }

        // Crear directorio del namespace si no existe
        char dir[32];
        snprintf(dir, sizeof(dir), "/%s", _ns);
        if (!LittleFS.exists(dir)) LittleFS.mkdir(dir);
        return true;
    }

    uint8_t  getUInt8 (const char* k, uint8_t  dv = 0)    override { uint8_t  v = dv; _read(k, &v, sizeof(v)); return v; }
    uint16_t getUInt16(const char* k, uint16_t dv = 0)    override { uint16_t v = dv; _read(k, &v, sizeof(v)); return v; }
    uint32_t getUInt32(const char* k, uint32_t dv = 0)    override { uint32_t v = dv; _read(k, &v, sizeof(v)); return v; }
    bool     getBool  (const char* k, bool     dv = false) override { uint8_t  v = dv ? 1 : 0; _read(k, &v, sizeof(v)); return v != 0; }

    size_t getString(const char* k, char* buf, size_t bufLen,
                     const char* dv = "") override {
        char path[48]; _path(k, path, sizeof(path));
        if (!LittleFS.exists(path)) {
            strncpy(buf, dv, bufLen - 1);
            buf[bufLen - 1] = '\0';
            return strlen(buf);
        }
        File f = LittleFS.open(path, "r");
        if (!f) { strncpy(buf, dv, bufLen - 1); buf[bufLen-1] = '\0'; return strlen(buf); }
        size_t n = f.readBytes(buf, bufLen - 1);
        buf[n] = '\0';
        f.close();
        return n;
    }

    bool putUInt8 (const char* k, uint8_t  v) override { return _write(k, &v, sizeof(v)); }
    bool putUInt16(const char* k, uint16_t v) override { return _write(k, &v, sizeof(v)); }
    bool putUInt32(const char* k, uint32_t v) override { return _write(k, &v, sizeof(v)); }
    bool putBool  (const char* k, bool     v) override { uint8_t b = v ? 1 : 0; return _write(k, &b, sizeof(b)); }

    bool putString(const char* k, const char* value) override {
        char path[48]; _path(k, path, sizeof(path));
        File f = LittleFS.open(path, "w");
        if (!f) return false;
        f.print(value);
        f.close();
        return true;
    }

    bool remove(const char* k) override {
        char path[48]; _path(k, path, sizeof(path));
        return LittleFS.remove(path);
    }

    void clear() override {
        char dir[32]; snprintf(dir, sizeof(dir), "/%s", _ns);
        // LittleFS no tiene rmdir recursivo; borramos archivo por archivo
        Dir d = LittleFS.openDir(dir);
        while (d.next()) LittleFS.remove(d.fileName());
    }

    void commit() override {
        // LittleFS escribe síncronamente, no necesita commit explícito
    }

private:
    char _ns[16];

    void _path(const char* key, char* buf, size_t bufLen) {
        snprintf(buf, bufLen, "/%s/%s", _ns, key);
    }

    bool _read(const char* key, void* buf, size_t len) {
        char path[48]; _path(key, path, sizeof(path));
        if (!LittleFS.exists(path)) return false;
        File f = LittleFS.open(path, "r");
        if (!f) return false;
        size_t n = f.read((uint8_t*)buf, len);
        f.close();
        return n == len;
    }

    bool _write(const char* key, const void* buf, size_t len) {
        char path[48]; _path(key, path, sizeof(path));
        File f = LittleFS.open(path, "w");
        if (!f) return false;
        size_t n = f.write((const uint8_t*)buf, len);
        f.close();
        return n == len;
    }
};

#else
// Plataforma no RP2040: stub vacío para evitar errores de compilación
// Si se incluye este archivo en otra plataforma, usar EEPROMStore o PreferencesStore
#include "EEPROMStore.h"
using FlashStore = EEPROMStore;
#endif

#endif // FLASH_STORE_H
