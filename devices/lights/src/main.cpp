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
#include "RGBIndicator.h"

// ── Módulo de Diagnóstico y Emparejamiento por USB (fácil de eliminar en producción) ──
#include "../shared/debug/TestSerial.h"

// ─── Instancias de módulos ───────────────────────────────────────────────────
ParamStore      params;
MeshConnection  connection(NODE_ID);       // NODE_ID definido en PinConfig.h
ColmenaNode     colmena(connection, params);
RelayBank       relays;
RGBIndicator    rgbLed;
TestSerial      testSerial;

// ─── Estado local ─────────────────────────────────────────────────────────────
static bool isRadioOk = false;

// ─────────────────────────────────────────────────────────────────────────────
void setup() {
    // 0. Diagnóstico e inspección Serial (fácil de eliminar en producción)
    testSerial.init(115200);

    // 1. Inicializar almacenamiento y cargar parámetros
    params.begin("colmena");

    // 2. Configurar identidad del nodo
    colmena.setNodeId(NODE_ID);
    colmena.setDeviceType(NODE_DEVICE_TYPE);  // Ej: DEV_LIGHT=0x02, DEV_PLUG=0x01
    colmena.setFeatures(NODE_FEATURES);       // Ej: FEAT_RELAY|FEAT_DIMMER
    colmena.load();

    // 3. Inicializar relays y LED RGB integrado — solo los pines que este dispositivo tiene
    relays.init(RELAY_COUNT, RELAY_PINS, RELAY_ACTIVE_LOW);
    rgbLed.init();

    // 4. Conectar a la red Mesh (intentar arranque sin bloquear si falla)
    connection.begin();

    // 5. Verificar salud física del chip de radio (¡Solo es error RF si el chip SPI no responde!)
    if (!connection.getRadio().isChipConnected()) {
        isRadioOk = false;
        rgbLed.showRfError();
        testSerial.printRfDiagnostics(false);
    } else {
        isRadioOk = true;
        colmena.startPairingWindow(NODE_NAME);   // Activar ventana de búsqueda automática por 50s
        rgbLed.startPairing();         // Iniciar animación de vinculación al alimentar el nodo
        testSerial.printRfDiagnostics(true);
    }

    // Conectar callback en testSerial para disparar la misma animación al mandar PAIR por USB
    testSerial.setPairCallback([]() {
        if (connection.getRadio().isChipConnected()) {
            isRadioOk = true;
            rgbLed.clearRfError();
            colmena.startPairingWindow(NODE_NAME);
            rgbLed.startPairing();
        } else {
            isRadioOk = false;
            rgbLed.showRfError();
        }
    });

    // 6. Botón de vinculación táctil (opcional) — activo solo si PAIR_BUTTON_PIN está definido
#ifdef PAIR_BUTTON_PIN
    colmena.initPairButton(PAIR_BUTTON_PIN, PAIR_BUTTON_ACTIVE_LOW);
#endif
}

// ─────────────────────────────────────────────────────────────────────────────
void loop() {
    // 0. Diagnóstico e interacción Serial por USB (siempre activo para responder órdenes aunque esté sin RF)
    testSerial.update(colmena, relays, isRadioOk, NODE_NAME, NODE_ID);

    // 1. Actualizar animación del LED RGB en tiempo real (efecto ola / verde / rojo) sin bloquear
    rgbLed.update();

    // 2. Operaciones RF: Solamente si el hardware de radio está SANO (evita congelamientos o esperas por error SPI)
    if (isRadioOk) {
        // Mantener red Mesh (update + checkConnection automático)
        connection.update();

        // Sincronizar y reintentar anuncio por 50s si el nodo está en ventana de vinculación
        colmena.tickPairing();

        // Procesar paquetes RF entrantes
        if (connection.available()) {
            RFPacket pkt;
            if (connection.receive(&pkt, sizeof(pkt))) {

                if (!Protocol_verify(&pkt)) return;  // Checksum inválido

                testSerial.logPacketRX(pkt);
                rgbLed.onPacketReceived(); // ¡Cualquier paquete recibido confirma vinculación exitosa!

                switch (pkt.command) {

                    case CMD_REPORT:
                    case CMD_DISCOVER:
                        // El master o un nodo pide anuncio — responder y anunciarse
                        colmena.announce(NODE_NAME);
                        break;

                    case CMD_UNPAIR:
                        colmena.unpair();
                        rgbLed.startPairing();
                        break;

                    case CMD_CONTROL: {
                        // Soportar formato bitwise en data[0..3] junto con bytes individuales en data[4..25] o data[0..]
                        uint32_t receivedMask = ((uint32_t)pkt.data[3] << 24) | ((uint32_t)pkt.data[2] << 16) | ((uint32_t)pkt.data[1] << 8) | pkt.data[0];
                        for (uint8_t i = 0; i < RELAY_COUNT && i < RelayBank::MAX_RELAYS; i++) {
                            bool chOn = (receivedMask & (1UL << i)) || (pkt.data[i] != 0) || (i + 4 < 26 && pkt.data[i + 4] != 0);
                            relays.setState(i, chOn);
                        }
                        if (isRadioOk) {
                            colmena.sendHeartbeat(relays.getMask());
                        }
                        break;
                    }

                    case CMD_ON:
                        relays.setState(pkt.data[0], true);
                        if (isRadioOk) {
                            colmena.sendHeartbeat(relays.getMask());
                        }
                        break;

                    case CMD_OFF:
                        relays.setState(pkt.data[0], false);
                        if (isRadioOk) {
                            colmena.sendHeartbeat(relays.getMask());
                        }
                        break;

                    case CMD_TOGGLE:
                        relays.toggle(pkt.data[0]);
                        if (isRadioOk) {
                            colmena.sendHeartbeat(relays.getMask());
                        }
                        break;

                    case CMD_ON_ALL:
                        relays.setAll(true);
                        if (isRadioOk) {
                            colmena.sendHeartbeat(relays.getMask());
                        }
                        break;

                    case CMD_OFF_ALL:
                        relays.setAll(false);
                        if (isRadioOk) {
                            colmena.sendHeartbeat(relays.getMask());
                        }
                        break;

                    case CMD_SET_MASK:
                        relays.setMask((uint16_t)pkt.data[0] | ((uint16_t)pkt.data[1] << 8));
                        if (isRadioOk) {
                            colmena.sendHeartbeat(relays.getMask());
                        }
                        break;

                    case CMD_CONFIG_SYNC:
                        colmena.applySync(pkt);
                        break;

                    default:
                        break;
                }
            }
        }

        // 3. Verificación y Heartbeat natural reactivo
        if (colmena.isHeartbeatDue()) {
            if (!connection.getRadio().isChipConnected()) {
                // Si se desconectó físicamente: avisa y se olvida (quedó desactivado)
                isRadioOk = false;
                rgbLed.showRfError();
                testSerial.printRfDiagnostics(false);
            } else {
                colmena.tickHeartbeat(relays.getMask());
            }
        }
    }

    // 4. Botón táctil/físico multifunción y recuperación reactiva ante eventos
#ifdef PAIR_BUTTON_PIN
    ButtonEvent btn = colmena.checkButtonEvent(NODE_NAME);

    // Si la radio estaba desactivada por error, re-verificar ÚNICAMENTE al presionar botón o al tocar el heartbeat programado
    if (!isRadioOk && (btn != BTN_NONE || colmena.isHeartbeatDue())) {
        if (connection.begin() && connection.getRadio().isChipConnected()) {
            // ¡Lo arreglaron o reconectaron! Al tiro todo nice y se olvida el error
            isRadioOk = true;
            rgbLed.clearRfError();
            colmena.announce(NODE_NAME);
            testSerial.printRfDiagnostics(true);
        } else {
            // Volvió a fallar o sigue desconectado: marca error
            rgbLed.showRfError();
            colmena.resetHeartbeatTimer();
        }
    }

    if (btn == BTN_SHORT_PRESS) {
        relays.toggleAll();
        if (isRadioOk) {
            colmena.sendHeartbeat(relays.getMask());
        }
    } else if (btn == BTN_PAIR_LONG_PRESS) {
        if (isRadioOk) {
            rgbLed.startPairing();
        } else {
            rgbLed.showRfError();
        }
    }
#endif
}
