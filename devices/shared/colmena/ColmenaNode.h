#ifndef COLMENA_NODE_H
#define COLMENA_NODE_H

/**
 * @file ColmenaNode.h (shared/colmena/)
 * @brief Lógica de colmena para nodos LEAF (lights, sensors, actuators).
 *
 * Extiende ColmenaBase con las operaciones específicas de los nodos que
 * se conectan al master: anuncio de presencia, heartbeat periódico,
 * aplicación de configuración recibida del master, y botón de vinculación.
 *
 * Uso en main.cpp de cualquier nodo leaf:
 * ─────────────────────────────────────────────────────────────────────
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
 *
 *     // Botón de vinculación (opcional) — definir PAIR_BUTTON_PIN en PinConfig.h
 *     colmena.initPairButton(PAIR_BUTTON_PIN);  // activeLow=true por defecto
 * }
 *
 * void loop() {
 *     conn.update();
 *     if (conn.available()) {
 *         RFPacket pkt;
 *         conn.receive(&pkt, sizeof(pkt));
 *         if (pkt.command == CMD_CONFIG_SYNC) colmena.applySync(pkt);
 *         if (pkt.command == CMD_REPORT)      colmena.announce(NODE_NAME);
 *     }
 *     colmena.tickHeartbeat(relays.getState(0));
 *     colmena.tickPairButton();  // Revisar botón — re-anuncia al master si se presiona
 * }
 * ─────────────────────────────────────────────────────────────────────
 *
 * Compatibilidad: ESP32 · ESP8266 · RP2040 · Raspberry Pi Pico · Arduino
 */

#include "colmena/ColmenaBase.h"
#include "protocol/ProtocolExt.h"
#include <Arduino.h>

// Tiempo mínimo entre activaciones del botón (anti-rebote + anti-spam)
#ifndef PAIR_BUTTON_DEBOUNCE_MS
  #define PAIR_BUTTON_DEBOUNCE_MS  50
#endif
#ifndef PAIR_BUTTON_COOLDOWN_MS
  #define PAIR_BUTTON_COOLDOWN_MS  3000
#endif

enum ButtonEvent {
    BTN_NONE = 0,
    BTN_SHORT_PRESS = 1,      // < 7s al soltar (para encender/apagar o alternar relays)
    BTN_PAIR_LONG_PRESS = 2   // >= 7s continuo (para modo vinculación por 50s)
};

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

    /** @brief Verifica si ha transcurrido el tiempo configurado para el próximo Heartbeat sin enviarlo. */
    bool isHeartbeatDue() const {
        return (millis() - _lastHeartbeatMs >= (unsigned long)_p.heartbeatInterval * 1000UL);
    }

    /** @brief Reinicia el contador del temporizador de Heartbeat al instante actual. */
    void resetHeartbeatTimer() {
        _lastHeartbeatMs = millis();
    }

    /**
     * @brief Procesa un paquete CMD_CONFIG_SYNC recibido del master.
     * Actualiza y persiste los nuevos parámetros de red de la colmena.
     * @param pkt  Paquete CMD_CONFIG_SYNC recibido
     */
    void applySync(const RFPacket& pkt);
    void unpair();

    // ── Botón de vinculación y control de Relays ──────────────────────

    /**
     * @brief Configura el pin del botón de vinculación.
     * Llama a pinMode internamente. Llamar en setup().
     *
     * @param pin       GPIO del botón. Definir PAIR_BUTTON_PIN en PinConfig.h.
     * @param activeLow true (default) = botón conectado a GND (pull-up interno).
     *                  false          = botón conectado a VCC (pull-down).
     */
    void initPairButton(uint8_t pin, bool activeLow = true);

    /**
     * @brief Evalúa el botón táctil o físico distinguiendo toque corto vs toque largo.
     *
     * - Si se suelta el botón tras mantenerlo entre 50ms y < 7000ms: retorna BTN_SHORT_PRESS.
     * - Si se mantiene presionado continuamente durante >= 7000ms (7 segundos): activa modo vinculación
     *   (startPairingWindow) y retorna BTN_PAIR_LONG_PRESS.
     *
     * @param nodeName  Nombre a usar en el announce en caso de vinculación.
     * @return BTN_NONE, BTN_SHORT_PRESS o BTN_PAIR_LONG_PRESS.
     */
    ButtonEvent checkButtonEvent(const char* nodeName);

    /**
     * @brief Revisa el estado del botón de vinculación (compatibilidad).
     * Retorna true únicamente cuando se activa el modo vinculación (>= 7 segundos).
     */
    bool tickPairButton(const char* nodeName);

    /**
     * @brief Inicia el modo de vinculación continua por ventana de 50 segundos.
     * Reintenta el anuncio y negociación DHCP periódicamente para igualar el tiempo del Gateway.
     * @param nodeName  Nombre legible del nodo
     */
    void startPairingWindow(const char* nodeName);

    /**
     * @brief Mantiene activa la ventana de vinculación de 50s. Llamado automáticamente por tickHeartbeat().
     */
    void tickPairing();

    /** @brief Devuelve true si el nodo está activamente en la ventana de vinculación. */
    bool isPairingWindowActive() const { return _isPairingMode; }

private:
    unsigned long _lastHeartbeatMs;

    // Botón de vinculación / control
    uint8_t       _pairPin;           // 255 = no configurado
    bool          _pairActiveLow;
    bool          _pairLastState;     // Estado anterior (para detección de flanco)
    bool          _pairLongPressTriggered; // True una vez disparada la vinculación de 7s
    unsigned long _pairDebounceMs;    // Timestamp del último cambio detectado
    unsigned long _pairLastAnnounce;  // Timestamp del último announce por botón

    // Ventana de vinculación de 50s en el Nodo
    bool          _isPairingMode;
    unsigned long _pairingStartMs;
    unsigned long _lastPairingRetryMs;
    char          _pairingNodeName[16];
};

#endif // COLMENA_NODE_H
