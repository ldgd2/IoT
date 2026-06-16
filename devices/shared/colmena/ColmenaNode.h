#ifndef COLMENA_NODE_H
#define COLMENA_NODE_H

/**
 * @file ColmenaNode.h (shared/colmena/)
 * @brief Lógica de colmena para nodos LEAF (lights, sensors, actuators).
 *
 * Extiende ColmenaBase con las operaciones específicas de los nodos que
 * se conectan al master: anuncio de presencia, heartbeat periódico y
 * aplicación de configuración recibida del master.
 *
 * Uso en main.cpp de cualquier nodo leaf:
 * ─────────────────────────────────────────────────────────────────────────
 * MeshConnection  conn(NODE_ID);
 * EEPROMStore     store;
 * ColmenaNode     colmena(conn, store);
 *
 * void setup() {
 *     store.begin("colmena");
 *     colmena.setNodeId(NODE_ID);
 *     colmena.setDeviceType(DEV_TYPE_LIGHT);
 *     colmena.setFeatures(FEATURE_RELAY);
 *     colmena.load();
 *     conn.begin();
 *     colmena.announce("Luz-01");
 * }
 *
 * void loop() {
 *     conn.update();
 *     if (conn.available()) {
 *         RFPacket pkt;
 *         conn.receive(&pkt, sizeof(pkt));
 *         if (pkt.command == CMD_CONFIG_SYNC) colmena.applySync(pkt);
 *     }
 *     colmena.tickHeartbeat(relays.getState(0));
 * }
 * ─────────────────────────────────────────────────────────────────────────
 *
 * Compatibilidad: ESP32 · ESP8266 · RP2040 · Raspberry Pi Pico · Arduino
 */

#include "colmena/ColmenaBase.h"
#include "protocol/ProtocolExt.h"

class ColmenaNode : public ColmenaBase {
public:
    ColmenaNode(IConnection& conn, IParamStore& store);

    /**
     * @brief Envía el paquete CMD_DISCOVER al master.
     * Incluye nombre del nodo, tipo de dispositivo y feature flags.
     * Llamar al final de setup(), después de que la conexión esté activa.
     * @param nodeName  Nombre legible del nodo (max 15 chars)
     */
    void announce(const char* nodeName);

    /**
     * @brief Envía un heartbeat manual al master con el estado actual.
     * Para casos donde se necesita reportar un evento específico.
     * @param relayMask    Bitmask de estados de relays (hasta 16 bits)
     * @param brightness   Nivel de brillo del relay 0 (0-255, 0 si no aplica)
     */
    void sendHeartbeat(uint16_t relayMask = 0, uint8_t brightness = 0);

    /**
     * @brief Heartbeat automático por tiempo — llamar en cada loop().
     * Envía el heartbeat solo cuando ha transcurrido el intervalo configurado.
     * @param relayMask  Estado actual de los relays (bitmask)
     * @param brightness Nivel de brillo
     */
    void tickHeartbeat(uint16_t relayMask = 0, uint8_t brightness = 0);

    /**
     * @brief Procesa un paquete CMD_CONFIG_SYNC recibido del master.
     * Actualiza y persiste los nuevos parámetros de red de la colmena.
     * @param pkt  Paquete CMD_CONFIG_SYNC recibido
     */
    void applySync(const RFPacket& pkt);

private:
    unsigned long _lastHeartbeatMs;
};

#endif // COLMENA_NODE_H
