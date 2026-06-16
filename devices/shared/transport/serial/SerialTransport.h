#ifndef SERIAL_TRANSPORT_H
#define SERIAL_TRANSPORT_H

/**
 * @file SerialTransport.h
 * @brief ITransport sobre Serial — JSON bidireccional para ESP8266, ESP32, Arduino.
 *
 * Protocolo JSON de comunicación con el HUB:
 *
 * ── Recepción (host → translator) ───────────────────────────────────────────
 * Línea JSON terminada en '\n':
 * {"dest":1, "cmd":1, "data":[0,0,...]}
 *   dest  → uint8_t Node ID destino
 *   cmd   → uint8_t Código de comando (CMD_*)
 *   data  → array de 26 uint8_t (payload, opcional, default 0)
 *
 * ── Envío (translator → host) ───────────────────────────────────────────────
 * Línea JSON terminada en '\n':
 * {"origin":1,"dest":0,"type":2,"cmd":4,"data":[1,0,0,...]}
 *   origin → uint8_t Node ID remitente
 *   dest   → uint8_t Node ID destino
 *   type   → uint8_t Tipo de dispositivo (DEV_TYPE_*)
 *   cmd    → uint8_t Código de comando
 *   data   → array de 26 uint8_t
 *
 * ── ACK (translator → host) ─────────────────────────────────────────────────
 * {"ack":true,"dest":1}
 * {"ack":false,"dest":1}
 *
 * ── Status/Log (translator → host) ──────────────────────────────────────────
 * {"log":"mensaje de texto"}
 */

#include "../ITransport.h"
#include <Arduino.h>
#include <ArduinoJson.h>

class SerialTransport : public ITransport {
public:
    /**
     * @param baudRate  Velocidad del puerto serial (default: 115200)
     */
    explicit SerialTransport(uint32_t baudRate = 115200);

    bool begin() override;
    bool available() override;
    bool readPacket(RFPacket& pkt) override;
    bool sendPacket(const RFPacket& pkt) override;
    bool sendAck(bool ok, uint8_t destId = 0) override;
    void sendStatus(const char* msg) override;

private:
    uint32_t _baudRate;

    // Buffer interno para acumular la línea entrante
    // (Serial.readStringUntil es bloqueante; usamos lectura char-a-char)
    static const uint8_t  RX_BUF_SIZE = 200;
    char     _rxBuf[RX_BUF_SIZE];
    uint8_t  _rxIdx;

    /**
     * @brief Lee caracteres de Serial hacia el buffer interno hasta encontrar '\n'.
     * No bloquea: retorna true solo cuando se completó una línea.
     */
    bool _readLine();
};

#endif // SERIAL_TRANSPORT_H
