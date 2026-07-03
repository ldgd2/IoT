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

// ─── Temporizadores ──────────────────────────────────────────────────────────
static unsigned long lastDisplayRefresh = 0;
static const unsigned long DISPLAY_REFRESH_MS   = 5000;
static const unsigned long HEARTBEAT_TIMEOUT_MS = 90000;

// ─────────────────────────────────────────────────────────────────────────────
void setup() {
    params.begin("colmena");
    colmena.load();

    // Display boot
    if (displayDriver.init()) {
        ui.drawBootScreen("Colmena IoT", "Gateway v1.0", "Iniciando...");
    }

    // Transport
    if (!pTransport->begin()) {
        ui.drawErrorScreen("E_TRANSPORT", "Init failed");
        while (1) {}
    }

    // Mesh master
    ui.drawBootScreen("Colmena IoT", "Gateway v1.0", "Init Mesh...");
    if (!connection.begin()) {
        ui.drawErrorScreen("E_RADIO", "Radio sin respuesta");
        pTransport->sendStatus("{\"error\":\"radio_not_responding\"}");
        while (1) {}
    }

    // Distribuir config a todos los nodos conocidos
    colmena.broadcastSync();
    // Pedir re-anuncio a nodos que ya estaban corriendo antes que el translator
    delay(100);
    colmena.broadcastPing();

    ui.drawStatusScreen("ACTIVO", 0, colmena.getParams().colmenaName, "Sistema listo");
}

// ─────────────────────────────────────────────────────────────────────────────
void loop() {
    // 1. Mantener red (update + DHCP)
    connection.update();

    // 2. RF → HUB
    if (connection.available()) {
        RFPacket pkt;
        if (connection.receive(&pkt, sizeof(pkt))) {
            if (!Protocol_verify(&pkt)) {
                pTransport->sendStatus("{\"warn\":\"bad_checksum\"}");
            } else {
                colmena.onPacketReceived(pkt);
                pTransport->sendPacket(pkt);
            }
        }
    }

    // 3. HUB → RF
    if (pTransport->available()) {
        RFPacket pkt;
        if (pTransport->readPacket(pkt)) {
            bool ok = connection.send(&pkt, sizeof(pkt), pkt.destId);
            pTransport->sendAck(ok, pkt.destId);
        }
    }

    // 4. Timeouts de heartbeat
    colmena.checkHeartbeatTimeouts(HEARTBEAT_TIMEOUT_MS);

    // 5. Refrescar display
    if (millis() - lastDisplayRefresh > DISPLAY_REFRESH_MS) {
        lastDisplayRefresh = millis();
        ui.drawStatusScreen("ACTIVO",
                             colmena.getOnlineCount(),
                             colmena.getParams().colmenaName,
                             "En operacion");
    }
}
