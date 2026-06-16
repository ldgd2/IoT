#ifndef MASTER_MESH_CONNECTION_H
#define MASTER_MESH_CONNECTION_H

/**
 * @file MasterMeshConnection.h (shared/mesh/)
 * @brief IConnection para el nodo MASTER (Node 0) de la red RF24Mesh.
 *
 * Extiende MeshConnection agregando:
 *   - mesh.DHCP() en update() — asigna direcciones RF a los nodos leaf
 *   - getNodeCount() — número de nodos actualmente enrutados
 *   - getLogicalNodeId() — resuelve dirección física → Node ID lógico
 *   - isConnected() siempre retorna true (el master ES la raíz de la red)
 *
 * Solo debe usarse en el translator/gateway (Node 0).
 * Los nodos leaf (lights, sensors) usan MeshConnection.
 *
 * Compatibilidad: ESP32 · ESP8266 · RP2040 · Raspberry Pi Pico · Arduino
 */

#include "mesh/MeshConnection.h"

class MasterMeshConnection : public MeshConnection {
public:
    /**
     * El master siempre es Node ID 0 (ADDR_MASTER).
     */
    MasterMeshConnection();

    // ── Overrides del master ─────────────────────────────────────────────────

    /**
     * @brief Mantenimiento de la red + DHCP.
     * El master asigna direcciones RF a los nodos que se conectan.
     * Llamar en cada iteración del loop().
     */
    void update() override;

    /**
     * @brief El master siempre está conectado — es la raíz de la red.
     * @return Siempre true
     */
    bool isConnected() override { return true; }

    /**
     * @brief No aplica al master — es la raíz, nunca pierde su dirección.
     * @return Siempre true
     */
    bool reconnect() override { return true; }

    // ── Info de la red ───────────────────────────────────────────────────────

    /**
     * @brief Número de nodos actualmente enrutados en la red.
     * @return Número de entradas en la tabla DHCP del mesh
     */
    uint8_t getNodeCount() const;

    /**
     * @brief Resuelve la dirección física RF a Node ID lógico.
     * @param fromNode  Dirección de red (de RF24NetworkHeader.from_node)
     * @return Node ID lógico (1-254), o -1 si no se encuentra
     */
    int getLogicalNodeId(uint16_t fromNode);
};

#endif // MASTER_MESH_CONNECTION_H
