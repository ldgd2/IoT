/**
 * @file main.cpp — translator / gateway
 * @brief Orquestador del gateway. Solo conecta módulos de shared/.
 *
 * ─── Módulos usados (todos de shared/) ──────────────────────────────────────
 *   MasterMeshConnection → red RF24Mesh como nodo master (Node 0 + DHCP)
 *   ColmenaMaster        → registro de nodos, broadcastSync
 *   ParamStore           → persistencia por plataforma
 *   SSD1306Driver        → OLED hardware (IDisplay)
 *   Renderer             → primitivas de dibujo sobre IDisplay
 *   UILayout             → pantallas completas sobre Renderer
 *   ITransport           → puente con HUB
 *     ├─ SerialTransport (ESP8266, ESP32, Arduino)
 *     └─ HIDTransport    (RP2040 con TinyUSB)
 *
 * ─── Módulos que este dispositivo NO usa ────────────────────────────────────
 *   RelayBank           → sin actuadores físicos (es un gateway)
 *   MeshConnection      → usa MasterMeshConnection (no el leaf)
 *   ColmenaNode         → usa ColmenaMaster (no el leaf)
 */

#include <Arduino.h>
#include <SPI.h>

// ── Config de hardware ──────────────────────────────────────────────────────
#include "PinConfig.h"
#include "RadioConfig.h"

// ── Protocolo compartido ────────────────────────────────────────────────────
#include "protocol/Protocol.h"
#include "protocol/ProtocolExt.h"

// ── Persistencia ─────────────────────────────────────────────────────────────
#include "params/PreferencesStore.h"
#include "params/FlashStore.h"
#include "params/EEPROMStore.h"

#if defined(IS_ESP32)
    using ParamStore = PreferencesStore;
#elif defined(IS_RP2040)
    using ParamStore = FlashStore;
#else
    using ParamStore = EEPROMStore;
#endif

// ── Red RF Mesh (master) ────────────────────────────────────────────────────
#include "mesh/MasterMeshConnection.h"

// ── Lógica de colmena (master) ───────────────────────────────────────────────
#include "colmena/ColmenaMaster.h"

// ── Display ──────────────────────────────────────────────────────────────────
#include "display/core/SSD1306Driver.h"
#include "display/render/Renderer.h"
#include "display/ui/UILayout.h"
#include "error/ColmenaError.h"

// ── Transport — selección compile-time ───────────────────────────────────────
#include "transport/ITransport.h"
#if defined(IS_RP2040) && defined(USE_TINYUSB)
    #include "transport/hid/HIDTransport.h"
    using TransportImpl = HIDTransport;
#else
    #include "transport/serial/SerialTransport.h"
    using TransportImpl = SerialTransport;
#endif

// ─── Instancias ──────────────────────────────────────────────────────────────
ParamStore            params;
MasterMeshConnection  connection;
ColmenaMaster         colmena(connection, params);

SSD1306Driver         displayDriver;
Renderer              renderer(displayDriver);
UILayout              ui(renderer);

TransportImpl         transport;
ITransport*           pTransport = &transport;

// ─── Temporizadores y Estado UI ──────────────────────────────────────────────
static unsigned long lastDisplayRefresh = 0;
static const unsigned long DISPLAY_REFRESH_MS   = 80; // ~12.5 FPS a tiempo real
static const unsigned long HEARTBEAT_TIMEOUT_MS = 90000;
static char lastActivityStr[64] = "Esperando paquetes...";
static char lastRxPktStr[32] = "RX: Ninguno";
static char lastTxPktStr[32] = "TX: Ninguno";
static uint8_t animFrame = 0;
static bool isPairingMode = false;
static unsigned long pairingStartTime = 0;
static const unsigned long PAIRING_TIMEOUT_MS = 50000;
static bool isRadioOk = false;

// ─────────────────────────────────────────────────────────────────────────────
void setup() {
    // 0. Si se usa SerialTransport, inicializar aquí el Serial.
    // Si se usa HIDTransport, inicializar TinyUSB.
    transport.begin();

    // 1. Inicializar Display PRIMERO y mostrar pantalla de carga ("Iniciando...")
    displayDriver.init();
    ui.drawBootScreen("Colmena IoT", "Gateway v1.0", "Iniciando...");
    delay(1200);

    ColmenaError::registerUI(&ui);
    ColmenaError::registerTransport(pTransport);

    // 2. Cargar parámetros desde EEPROM/Flash
    params.begin("colmena_gw");

    // 3. Configurar identidad del Master (Gateway siempre es Node 0)
    colmena.setNodeId(0);
    colmena.setDeviceType(DEV_TYPE_GATEWAY);

    // 4. Inicializar radio en su canal y dataRate configurados
    if (connection.begin() && connection.getRadio().isChipConnected()) {
        isRadioOk = true;
        ColmenaError::clear();
        pTransport->sendStatus("{\"status\":\"radio_ok\"}");
        ui.drawBootScreen("Colmena IoT", "Gateway v1.0", "Radio OK");
        delay(800);
        colmena.broadcastSync();
        delay(80);
        colmena.broadcastPing();
        snprintf(lastActivityStr, sizeof(lastActivityStr), "Red iniciada en CH %d", colmena.getParams().rfChannel);
    } else {
        isRadioOk = false;
        ui.drawBootScreen("Colmena IoT", "Gateway v1.0", "ERR: Radio NRF24");
        delay(1200);
        ColmenaError::raise(ERR_RADIO_INIT_FAIL);
        pTransport->sendStatus("{\"error\":\"radio_init_failed\"}");
        snprintf(lastActivityStr, sizeof(lastActivityStr), "ERR: Radio NRF24 fallo");
    }
}

// ─────────────────────────────────────────────────────────────────────────────
void loop() {
    // 1. Mantener red Mesh y procesar paquetes RF entrantes SOLAMENTE si el radio funciona (evita cuelgues de bus)
    if (isRadioOk) {
        connection.update();

        // 2. RF → HUB
        if (connection.available()) {
            RFPacket pkt;
            if (connection.receive(&pkt, sizeof(pkt))) {
                if (!Protocol_verify(&pkt)) {
                    pTransport->sendStatus("{\"warn\":\"bad_checksum\"}");
                    snprintf(lastActivityStr, sizeof(lastActivityStr), "ERR: Checksum invalido");
                    ColmenaError::raise(ERR_PACKET_CORRUPT);
                } else {
                    snprintf(lastRxPktStr, sizeof(lastRxPktStr), "RX: ID %u CMD 0x%02X", pkt.originId, pkt.command);
                    bool isUnknown = (colmena.findNode(pkt.originId) == nullptr);
                    bool isDiscover = (pkt.command == CMD_DISCOVER);

                    // Registrar siempre en tabla interna para recuperar nodos tras reinicio de RAM del traductor
                    colmena.onPacketReceived(pkt);

                    if (isDiscover || isUnknown) {
                        const NodeInfo* n = colmena.findNode(pkt.originId);
                        if (n) {
                            snprintf(lastTxPktStr, sizeof(lastTxPktStr), "TX: SYNC ID %u", n->nodeId);
                            ui.drawDeviceDetectedAnimation(n->name, n->nodeId, n->deviceType);
                            if (isPairingMode || isDiscover) {
                                if (isPairingMode) {
                                    isPairingMode = false;
                                }
                                char pairBuf[192];
                                snprintf(pairBuf, sizeof(pairBuf), "{\"event\":\"pairing_success\",\"status\":\"paired\",\"nodeId\":%u,\"name\":\"%s\",\"type\":%u,\"features\":%u}", n->nodeId, n->name, n->deviceType, n->features);
                                pTransport->sendStatus(pairBuf);
                                snprintf(lastActivityStr, sizeof(lastActivityStr), "Nuevo nodo detectado");
                            }
                        }
                    }

                    snprintf(lastActivityStr, sizeof(lastActivityStr), "RX Nodo %d (CMD 0x%02X)", pkt.originId, pkt.command);
                    pTransport->sendPacket(pkt);
                }
            }
        }
    }

    // 3. HUB → RF o comandos de control desde el frontend (Se ejecuta SIEMPRE para no desconectar ni bloquear el Hub)
    if (pTransport->available()) {
        RFPacket pkt;
        if (pTransport->readPacket(pkt)) {
            // Si el frontend envía CMD_ACK_ERROR, ¡aceptamos/limpiamos el error para que deje de salir en display!
            if (pkt.command == CMD_ACK_ERROR) {
                uint16_t errCodeAck = (uint16_t)pkt.data[0] | ((uint16_t)pkt.data[1] << 8);
                ColmenaError::acknowledge(errCodeAck);
                snprintf(lastActivityStr, sizeof(lastActivityStr), "Error #%u aceptado", errCodeAck);
                pTransport->sendAck(true, pkt.destId);
            } else if (pkt.command == CMD_PAIR_START) {
                isPairingMode = true;
                pairingStartTime = millis();
                snprintf(lastTxPktStr, sizeof(lastTxPktStr), "TX: Buscando...");
                snprintf(lastRxPktStr, sizeof(lastRxPktStr), "RX: Ninguno");
                snprintf(lastActivityStr, sizeof(lastActivityStr), "Modo vinculacion ACTIVO");
                pTransport->sendAck(true, pkt.destId);
                // Enviar un CMD_REPORT broadcast para que todos los dispositivos cercanos se anuncien de inmediato
                if (isRadioOk) {
                    colmena.broadcastPing();
                }
            } else if (pkt.command == CMD_PAIR_STOP) {
                isPairingMode = false;
                snprintf(lastActivityStr, sizeof(lastActivityStr), "Vinculacion finalizada");
                pTransport->sendAck(true, pkt.destId);
            } else if (pkt.command == CMD_UNPAIR) {
                colmena.removeNode(pkt.destId);
                if (isRadioOk) {
                    connection.send(&pkt, sizeof(pkt), pkt.destId);
                }
                snprintf(lastActivityStr, sizeof(lastActivityStr), "Desvinculado Nodo %u", pkt.destId);
                pTransport->sendAck(true, pkt.destId);
            } else {
                bool ok = false;
                if (isRadioOk) {
                    ok = connection.send(&pkt, sizeof(pkt), pkt.destId);
                    // Si el envío falló, verificamos de forma reactiva si el chip se desconectó físicamente
                    if (!ok && !connection.getRadio().isChipConnected()) {
                        // Avisa y se olvida (quedó desactivado)
                        isRadioOk = false;
                        ColmenaError::raise(ERR_RADIO_INIT_FAIL, "NRF24 Desconectado");
                        pTransport->sendStatus("{\"error\":\"radio_lost\",\"code\":101}");
                        snprintf(lastActivityStr, sizeof(lastActivityStr), "ERR: Radio NRF24 Desconectado");
                    }
                }
                snprintf(lastTxPktStr, sizeof(lastTxPktStr), "TX: ID %u CMD 0x%02X", pkt.destId, pkt.command);
                pTransport->sendAck(ok, pkt.destId);
                snprintf(lastActivityStr, sizeof(lastActivityStr), "TX -> Nodo %d (%s)", pkt.destId, ok ? "OK" : "Fallo RF");
            }
        }
    }

    // 4. Timeouts de heartbeat
    colmena.checkHeartbeatTimeouts(HEARTBEAT_TIMEOUT_MS);

    // Mantenimiento de red frecuente SOLO si el radio está operativo para no perder paquetes ni gastar CPU en error
    if (isRadioOk) {
        connection.update();
    } else {
        // Si el radio estaba desactivado por error, intentamos recuperar ÚNICAMENTE al llegar una orden por USB/Serial o en eventos largos
        static unsigned long lastReactiveEvent = 0;
        if (millis() - lastReactiveEvent > 30000UL) { // Evento espaciado largo natural (30s) sin chequear cada foking rato
            lastReactiveEvent = millis();
            if (connection.begin() && connection.getRadio().isChipConnected()) {
                // Al tiro todo nice y se olvida el error
                isRadioOk = true;
                ColmenaError::clear();
                pTransport->sendStatus("{\"status\":\"radio_recovered\",\"code\":0}");
                snprintf(lastActivityStr, sizeof(lastActivityStr), "Radio RF recuperado OK");
            }
        }
    }

    // 5. Refrescar display a tiempo real (~12.5 FPS)
    if (millis() - lastDisplayRefresh > DISPLAY_REFRESH_MS) {
        lastDisplayRefresh = millis();
        animFrame++;
        // Si hay un error activo, mostramos su animación fluida en tiempo real
        if (ColmenaError::hasActiveError()) {
            ColmenaError::renderActiveError(animFrame);
        } else if (isPairingMode) {
            if (millis() - pairingStartTime > PAIRING_TIMEOUT_MS) {
                isPairingMode = false;
                snprintf(lastActivityStr, sizeof(lastActivityStr), "Tiempo vinculacion agotado");
                pTransport->sendStatus("{\"event\":\"pairing_timeout\"}");
            } else {
                ui.drawPairingAnimation(colmena.getParams().colmenaName, (animFrame / 3) % 4, lastRxPktStr, lastTxPktStr);
            }
        } else {
            // Rotar cada 10 segundos (10000 ms) entre pantalla 1 (General) y pantalla 2 (Red)
            unsigned long secCycle = (millis() / 10000) % 2;
            if (secCycle == 0) {
                ui.drawLiveStatusScreen("ACTIVO",
                                        colmena.getOnlineCount(),
                                        colmena.getParams().colmenaName,
                                        lastActivityStr,
                                        animFrame);
            } else {
                ui.drawNetworkStatsScreen("ACTIVO",
                                          colmena.getParams().rfChannel,
                                          colmena.getParams().rfDataRate,
                                          #if defined(IS_RP2040) && defined(USE_TINYUSB)
                                            "USB HID",
                                          #else
                                            "Serial JSON",
                                          #endif
                                          animFrame);
            }
        }
    }
}
