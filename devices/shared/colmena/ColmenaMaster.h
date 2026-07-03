#ifndef COLMENA_MASTER_H
#define COLMENA_MASTER_H

/**
 * @file ColmenaMaster.h (shared/colmena/)
 * @brief Lógica de colmena para el nodo MASTER (translator/gateway).
 *
 * Extiende ColmenaBase con las operaciones específicas del gateway:
 *   - Registro y rastreo de todos los nodos conectados
 *   - Procesamiento de paquetes CMD_DISCOVER y CMD_HEARTBEAT
 *   - Broadcast de CMD_CONFIG_SYNC a toda la red
 *   - Detección de nodos offline por timeout de heartbeat
 *
 * Uso en main.cpp del translator:
 * ─────────────────────────────────────────────────────────────────────────
 * MasterMeshConnection conn;
 * PreferencesStore     store;
 * ColmenaMaster        colmena(conn, store);
 *
 * void setup() {
 *     store.begin("colmena");
 *     colmena.load();
 *     conn.begin();
 *     colmena.broadcastSync();   // Enviar config a toda la red al arrancar
 * }
 *
 * void loop() {
 *     conn.update();
 *     if (conn.available()) {
 *         RFPacket pkt;
 *         conn.receive(&pkt, sizeof(pkt));
 *         colmena.onPacketReceived(pkt);   // Actualiza registro automáticamente
 *         transport.sendPacket(pkt);       // Reenviar al HUB
 *     }
 *     colmena.checkHeartbeatTimeouts(90000);  // 90s sin HB → offline
 * }
 * ─────────────────────────────────────────────────────────────────────────
 *
 * Compatibilidad: ESP32 · ESP8266 · RP2040 · Raspberry Pi Pico · Arduino
 */

#include "colmena/ColmenaBase.h"
#include "protocol/ProtocolExt.h"
#include <Arduino.h>

// Máximo de nodos que el master puede rastrear simultáneamente
#define COLMENA_MAX_NODES  32

struct NodeInfo {
    uint8_t  nodeId;              // Node ID lógico (1-254)
    uint8_t  deviceType;          // DEV_TYPE_*
    uint8_t  features;            // FEATURE_* bitmask
    char     name[17];            // Nombre recibido en CMD_DISCOVER
    bool     online;              // true = heartbeat reciente
    uint32_t lastHeartbeatMs;     // millis() del último heartbeat
    uint16_t relayMask;           // Estado actual de relays (bitmask)
};

class ColmenaMaster : public ColmenaBase {
public:
    ColmenaMaster(IConnection& conn, IParamStore& store);

    /**
     * @brief Procesa cualquier paquete recibido de la red.
     * Actualiza el registro de nodos según CMD_DISCOVER y CMD_HEARTBEAT.
     * Llamar por cada paquete recibido en loop().
     * @param pkt  Paquete recibido
     */
    void onPacketReceived(const RFPacket& pkt);

    /**
     * @brief Envía CMD_CONFIG_SYNC a todos los nodos (broadcast).
     * Distribuye el canal RF, datarate, heartbeat interval y nombre de red.
     * Llamar al arrancar y cuando cambie la configuración.
     */
    void broadcastSync();

    /**
     * @brief Envía CMD_REPORT broadcast para que todos los nodos ya encendidos
     * re-ejecuten su announce(). Útil cuando el translator arranca mientras
     * los nodos ya están corriendo y el announce inicial se perdíde.
     * Llamar en setup() después de broadcastSync().
     */
    void broadcastPing();

    /**
     * @brief Envía CMD_CONFIG_SYNC a un nodo específico.
     * @param destId  Node ID del nodo destino
     */
    void sendSync(uint8_t destId);

    /**
     * @brief Marca como offline los nodos sin heartbeat reciente.
     * Llamar periódicamente en loop() para detectar nodos caídos.
     * @param timeoutMs  Tiempo máximo sin heartbeat en milisegundos
     */
    void checkHeartbeatTimeouts(uint32_t timeoutMs);

    // ── Consultas del registro de nodos ──────────────────────────────────────

    /** @brief Número de nodos registrados (online y offline). */
    uint8_t getNodeCount() const { return _nodeCount; }

    /** @brief Número de nodos actualmente online. */
    uint8_t getOnlineCount() const;

    /**
     * @brief Acceso a un NodeInfo por índice.
     * @return nullptr si el índice está fuera de rango
     */
    const NodeInfo* getNode(uint8_t idx) const;

    /**
     * @brief Busca un nodo por su Node ID.
     * @return nullptr si no se encuentra
     */
    const NodeInfo* findNode(uint8_t nodeId) const;

private:
    NodeInfo _nodes[COLMENA_MAX_NODES];
    uint8_t  _nodeCount;

    NodeInfo* _findOrCreate(uint8_t nodeId);
    void      _buildSyncPacket(RFPacket& pkt, uint8_t destId);
};

#endif // COLMENA_MASTER_H
