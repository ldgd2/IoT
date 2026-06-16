#ifndef MESH_CONNECTION_H
#define MESH_CONNECTION_H

/**
 * @file MeshConnection.h (shared/mesh/)
 * @brief IConnection para nodos LEAF de la red RF24Mesh.
 *
 * Implementación de IConnection usando RF24 + RF24Network + RF24Mesh.
 * Para nodos que NO son el master: lights, sensors, actuators, etc.
 *
 * Requiere que el dispositivo tenga en su include path (via platformio.ini):
 *   - PinConfig.h  → define CE_PIN, CSN_PIN
 *   - RadioConfig.h → define RF_CHANNEL, RF_DATARATE
 *
 * El nodo master (translator/gateway) usa MasterMeshConnection.
 *
 * Compatibilidad: ESP32 · ESP8266 · RP2040 · Raspberry Pi Pico · Arduino
 */

#include "connection/IConnection.h"
#include "PinConfig.h"
#include "RadioConfig.h"
#include <RF24.h>
#include <RF24Network.h>
#include <RF24Mesh.h>

#ifndef IRQ_PIN
#define IRQ_PIN -1
#endif

#if defined(ESP8266) || defined(ESP32)
  #ifndef ISR_PREFIX
    #define ISR_PREFIX IRAM_ATTR
  #endif
#else
  #define ISR_PREFIX
#endif

class MeshConnection : public IConnection {
public:
    /**
     * @param nodeId  Node ID de este nodo en la red (1-254 para nodos leaf)
     * @param irqPin  Pin IRQ conectado al nRF24L01 (por defecto IRQ_PIN)
     */
    explicit MeshConnection(uint8_t nodeId, int8_t irqPin = IRQ_PIN);

    // ── IConnection ──────────────────────────────────────────────────────────
    bool    begin()    override;
    void    update()   override;
    bool    send(const void* data, size_t len, uint8_t destId) override;
    bool    receive(void* buf, size_t len) override;
    bool    available() override;
    bool    isConnected() override;
    bool    reconnect() override;
    uint8_t getNodeId() const override { return _nodeId; }

    // ── Acceso interno (para extensiones) ────────────────────────────────────
    RF24&        getRadio()   { return _radio;   }
    RF24Network& getNetwork() { return _network; }
    RF24Mesh&    getMesh()    { return _mesh;    }

    // ── Manejo de Interrupciones (IRQ) ───────────────────────────────────────
    static volatile bool rfDataReady;
    static void ISR_PREFIX rfInterruptHandler();

protected:
    bool        shouldPerformUpdate();
    int8_t      _irqPin;
    uint8_t     _nodeId;
    RF24        _radio;
    RF24Network _network;
    RF24Mesh    _mesh;
};

#endif // MESH_CONNECTION_H
