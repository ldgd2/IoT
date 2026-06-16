/**
 * @file main.cpp — lights
 * @brief Orquestador del nodo de iluminación. Solo conecta módulos de shared/.
 *
 * Este archivo NO contiene lógica. Solo:
 *   1. Selecciona las implementaciones concretas según la plataforma
 *   2. Instancia los módulos que este dispositivo necesita
 *   3. Llama a sus métodos en setup() y loop()
 *
 * ─── Módulos usados (todos de shared/) ──────────────────────────────────────
 *   RelayBank       → N relays (definidos en PinConfig.h)
 *   MeshConnection  → red RF24Mesh como nodo leaf
 *   ColmenaNode     → lógica de hive: announce + heartbeat + applySync
 *   ParamStore      → persistencia por plataforma
 *
 * ─── Módulos que este dispositivo NO usa ────────────────────────────────────
 *   Display (IDisplay, Renderer, UILayout)  → sin pantalla
 *   Transport (Serial, HID)                 → solo el translator
 *   MasterMeshConnection                    → solo el gateway
 *   ColmenaMaster                           → solo el gateway
 */

#include <Arduino.h>
#include <SPI.h>

// ── Config de hardware (específico de este dispositivo) ─────────────────────
#include "PinConfig.h"
#include "RadioConfig.h"

// ── Protocolo compartido ────────────────────────────────────────────────────
#include "protocol/Protocol.h"
#include "protocol/ProtocolExt.h"

// ── Persistencia — selección compile-time según plataforma ──────────────────
#include "params/PreferencesStore.h"
#include "params/FlashStore.h"
#include "params/EEPROMStore.h"

#if defined(IS_ESP32)
    using ParamStore = PreferencesStore;
#elif defined(IS_RP2040)
    using ParamStore = FlashStore;
#else
    using ParamStore = EEPROMStore;   // Arduino, ESP8266
#endif

// ── Red RF Mesh (nodo leaf) ─────────────────────────────────────────────────
#include "mesh/MeshConnection.h"

// ── Lógica de colmena (leaf: announce + heartbeat + applySync) ───────────────
#include "colmena/ColmenaNode.h"

// ── Actuadores ───────────────────────────────────────────────────────────────
#include "actuators/relay/RelayBank.h"

// ─── Instancias de módulos ───────────────────────────────────────────────────
ParamStore      params;
MeshConnection  connection(NODE_ID);       // NODE_ID definido en PinConfig.h
ColmenaNode     colmena(connection, params);
RelayBank       relays;

// ─── Estado local ─────────────────────────────────────────────────────────────
static bool      reconectando = false;

// ─────────────────────────────────────────────────────────────────────────────
void setup() {
    // 1. Inicializar almacenamiento y cargar parámetros
    params.begin("colmena");

    // 2. Configurar identidad del nodo
    colmena.setNodeId(NODE_ID);
    colmena.setDeviceType(NODE_DEVICE_TYPE);  // Ej: DEV_LIGHT=0x02, DEV_PLUG=0x01
    colmena.setFeatures(NODE_FEATURES);       // Ej: FEAT_RELAY|FEAT_DIMMER
    colmena.load();

    // 3. Inicializar relays — solo los pines que este dispositivo tiene
    //    RELAY_PINS y RELAY_COUNT definidos en PinConfig.h
    relays.init(RELAY_COUNT, RELAY_PINS, RELAY_ACTIVE_LOW);

    // 4. Conectar a la red Mesh
    if (!connection.begin()) {
        // Sin conexión → quedar en standby local
        // Los relays siguen operando con el último estado guardado
        return;
    }

    // 5. Anunciar presencia al master
    colmena.announce(NODE_NAME);   // NODE_NAME definido en PinConfig.h
}

// ─────────────────────────────────────────────────────────────────────────────
void loop() {
    // 1. Mantener red Mesh (update + checkConnection automático)
    connection.update();

    // 2. Reconexión automática si se perdió la red
    if (!connection.isConnected()) {
        if (!reconectando) {
            reconectando = true;
        }
        bool ok = connection.reconnect();
        if (ok) {
            reconectando = false;
            colmena.announce(NODE_NAME);  // Re-anunciar tras reconectar
        }
        return;
    }
    reconectando = false;

    // 3. Procesar paquetes RF entrantes
    if (connection.available()) {
        RFPacket pkt;
        if (connection.receive(&pkt, sizeof(pkt))) {

            if (!Protocol_verify(&pkt)) return;  // Checksum inválido

            switch (pkt.command) {

                case CMD_ON:
                    relays.setState(pkt.data[0], true);
                    break;

                case CMD_OFF:
                    relays.setState(pkt.data[0], false);
                    break;

                case CMD_TOGGLE:
                    relays.toggle(pkt.data[0]);
                    break;

                case CMD_ON_ALL:
                    relays.setAll(true);
                    break;

                case CMD_OFF_ALL:
                    relays.setAll(false);
                    break;

                case CMD_SET_MASK:
                    // data[0..1] = bitmask de 16 relays
                    relays.setMask((uint16_t)pkt.data[0] | ((uint16_t)pkt.data[1] << 8));
                    break;

                case CMD_CONFIG_SYNC:
                    colmena.applySync(pkt);
                    break;

                default:
                    break;
            }
        }
    }

    // 4. Heartbeat automático (envía cada heartbeatInterval segundos)
    colmena.tickHeartbeat(relays.getMask());
}
