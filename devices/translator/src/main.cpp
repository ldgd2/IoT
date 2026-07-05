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
static uint8_t animFrame = 0;
static bool isPairingMode = false;
static unsigned long pairingStartTime = 0;
static const unsigned long PAIRING_TIMEOUT_MS = 60000;
static bool isRadioOk = false;

// ─────────────────────────────────────────────────────────────────────────────
void setup() {
    params.begin("colmena");
    colmena.load();

    // Display boot con retraso de estabilización integrado en driver
    if (displayDriver.init()) {
        // Registramos la interfaz gráfica y el transporte en el sistema central de errores
        ColmenaError::registerUI(&ui);
        ColmenaError::registerTransport(pTransport);
        // 1. Animación fluida de entrada a tiempo real
        ui.drawIntroAnimation();
    }

    // Transport
    if (!pTransport->begin()) {
        ColmenaError::raise(ERR_HUB_DISCONNECTED);
        while (1) {
            delay(500);
        }
    }

    // Mesh master
    ui.drawBootScreen("Colmena IoT", "Gateway v1.0", "Iniciando Radio...");
    if (!connection.begin()) {
        ColmenaError::raise(ERR_RADIO_INIT_FAIL);
        pTransport->sendStatus("{\"error\":\"radio_not_responding\"}");
        isRadioOk = false;
        snprintf(lastActivityStr, sizeof(lastActivityStr), "ERR: Radio RF no detectado");
    } else {
        isRadioOk = true;
        // Distribuir config a todos los nodos conocidos
        colmena.broadcastSync();
        delay(80);
        colmena.broadcastPing();
        snprintf(lastActivityStr, sizeof(lastActivityStr), "Red lista. Esperando...");
    }

    ui.drawLiveStatusScreen("ACTIVO", colmena.getOnlineCount(), colmena.getParams().colmenaName, lastActivityStr, 0);
}

// ─────────────────────────────────────────────────────────────────────────────
void loop() {
    // 0. Si el radio falló al iniciar, reintentar cada 3 segundos en segundo plano sin bloquear el USB/HID
    if (!isRadioOk) {
        static unsigned long lastRadioRetry = 0;
        if (millis() - lastRadioRetry > 3000) {
            lastRadioRetry = millis();
            if (connection.begin()) {
                isRadioOk = true;
                ColmenaError::clear();
                pTransport->sendStatus("{\"status\":\"radio_recovered\"}");
                colmena.broadcastSync();
                delay(80);
                colmena.broadcastPing();
                snprintf(lastActivityStr, sizeof(lastActivityStr), "Radio RF recuperado");
            }
        }
    } else {
        // 1. Mantener red (update + DHCP) solo si el radio funciona
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
                    bool isNewOrDiscover = (pkt.command == CMD_DISCOVER) || (colmena.findNode(pkt.originId) == nullptr);
                    colmena.onPacketReceived(pkt);
                    
                    // Si es un dispositivo nuevo o que se está vinculando, ¡mostrar animación en tiempo real!
                    if (isNewOrDiscover) {
                        const NodeInfo* n = colmena.findNode(pkt.originId);
                        if (n) {
                            ui.drawDeviceDetectedAnimation(n->name, n->nodeId, n->deviceType);
                            if (isPairingMode) {
                                isPairingMode = false;
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

    // 3. HUB → RF o comandos de control desde el frontend (Se ejecuta SIEMPRE para no desconectar al Hub)
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
                snprintf(lastActivityStr, sizeof(lastActivityStr), "Modo vinculacion ACTIVO");
                pTransport->sendAck(true, pkt.destId);
            } else if (pkt.command == CMD_PAIR_STOP) {
                isPairingMode = false;
                snprintf(lastActivityStr, sizeof(lastActivityStr), "Vinculacion finalizada");
                pTransport->sendAck(true, pkt.destId);
            } else {
                bool ok = false;
                if (isRadioOk) {
                    ok = connection.send(&pkt, sizeof(pkt), pkt.destId);
                }
                pTransport->sendAck(ok, pkt.destId);
                snprintf(lastActivityStr, sizeof(lastActivityStr), "TX -> Nodo %d (%s)", pkt.destId, ok ? "OK" : "Fallo RF");
            }
        }
    }

    // 4. Timeouts de heartbeat
    colmena.checkHeartbeatTimeouts(HEARTBEAT_TIMEOUT_MS);

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
            } else {
                ui.drawPairingAnimation(colmena.getParams().colmenaName, (animFrame / 3) % 4);
            }
        } else {
            ui.drawLiveStatusScreen("ACTIVO",
                                    colmena.getOnlineCount(),
                                    colmena.getParams().colmenaName,
                                    lastActivityStr,
                                    animFrame);
        }
    }
}
