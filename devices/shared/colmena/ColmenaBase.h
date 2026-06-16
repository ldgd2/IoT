#ifndef COLMENA_BASE_H
#define COLMENA_BASE_H

/**
 * @file ColmenaBase.h (shared/colmena/)
 * @brief Clase base de la configuración de colmena — compartida por todos los nodos.
 *
 * Contiene los parámetros de red comunes y la lógica de persistencia
 * que es idéntica para TODOS los tipos de nodo (leaf y master).
 *
 * Jerarquía:
 *   ColmenaBase          ← parámetros + load/save/reset (este archivo)
 *   ├── ColmenaNode      ← nodos leaf: announce, heartbeat, applySync
 *   └── ColmenaMaster    ← gateway: registro de nodos, broadcastSync
 *
 * Los dispositivos instancian la clase concreta que necesitan:
 *   lights/sensors     → ColmenaNode
 *   translator/gateway → ColmenaMaster
 *
 * Compatibilidad: ESP32 · ESP8266 · RP2040 · Raspberry Pi Pico · Arduino
 */

#include "connection/IConnection.h"
#include "params/IParamStore.h"
#include "protocol/Protocol.h"
#include <stdint.h>
#include <string.h>

// ─────────────────────────────────────────────────────────────────────────────
// Parámetros de la colmena — compartidos y replicables entre todos los nodos
// ─────────────────────────────────────────────────────────────────────────────
struct ColmenaParams {
    uint8_t  nodeId;             // ID único de este nodo (1-254 leaf, 0 master)
    uint8_t  rfChannel;          // Canal RF de toda la colmena (0-125)
    uint8_t  rfDataRate;         // 0=250kbps, 1=1Mbps, 2=2Mbps
    uint8_t  heartbeatInterval;  // Intervalo de heartbeat en segundos
    uint8_t  deviceType;         // Tipo de dispositivo (DEV_TYPE_*)
    uint8_t  features;           // Feature flags (FEATURE_* bitmask)
    uint8_t  fwVersion;          // Versión de firmware (BCD: 0x12 = v1.2)
    char     colmenaName[12];    // Nombre de la red (null-terminated)
};

// Defaults compile-time (pueden ser overrideados con -D en platformio.ini)
#ifndef DEFAULT_RF_CHANNEL
  #define DEFAULT_RF_CHANNEL       100
#endif
#ifndef DEFAULT_RF_DATARATE
  #define DEFAULT_RF_DATARATE      0
#endif
#ifndef DEFAULT_HEARTBEAT_SECS
  #define DEFAULT_HEARTBEAT_SECS   60
#endif
#ifndef DEFAULT_COLMENA_NAME
  #define DEFAULT_COLMENA_NAME     "Colmena"
#endif

class ColmenaBase {
public:
    /**
     * @param conn   Referencia a la conexión de red activa
     * @param store  Referencia al almacenamiento persistente
     */
    ColmenaBase(IConnection& conn, IParamStore& store);

    // ── Ciclo de vida de la configuración ────────────────────────────────────

    /**
     * @brief Carga parámetros desde el almacenamiento persistente.
     * Si una clave no existe, se usa el valor default. Llamar en setup().
     */
    void load();

    /**
     * @brief Guarda los parámetros actuales en el almacenamiento.
     */
    void save();

    /**
     * @brief Restaura los defaults de compilación y borra el almacenamiento.
     * Equivalente a factory reset de los parámetros de red.
     */
    void reset();

    // ── Acceso a parámetros ───────────────────────────────────────────────────
    const ColmenaParams& getParams() const { return _p; }

    void setNodeId(uint8_t id)              { _p.nodeId = id; }
    void setDeviceType(uint8_t type)        { _p.deviceType = type; }
    void setFeatures(uint8_t features)      { _p.features = features; }
    void setHeartbeatInterval(uint8_t secs) { _p.heartbeatInterval = secs; }
    void setColmenaName(const char* name) {
        strncpy(_p.colmenaName, name, sizeof(_p.colmenaName) - 1);
        _p.colmenaName[sizeof(_p.colmenaName) - 1] = '\0';
    }

protected:
    IConnection&  _conn;
    IParamStore&  _store;
    ColmenaParams _p;

    void _loadDefaults();
};

#endif // COLMENA_BASE_H
