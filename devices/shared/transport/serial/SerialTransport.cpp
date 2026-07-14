#include "SerialTransport.h"
#include <string.h>

SerialTransport::SerialTransport(uint32_t baudRate)
    : _baudRate(baudRate), _rxIdx(0)
{
    memset(_rxBuf, 0, sizeof(_rxBuf));
}

bool SerialTransport::begin() {
    Serial.begin(_baudRate);
    // Esperar a que el puerto esté listo (importante en Arduino/ESP boards)
    unsigned long t = millis();
    while (!Serial && (millis() - t < 3000)) {}

    // Anunciar al HUB que el translator está listo
    Serial.println("{\"status\":\"translator_ready\"}");
    return true;
}

bool SerialTransport::_readLine() {
    while (Serial.available()) {
        char c = (char)Serial.read();
        if (c == '\n' || c == '\r') {
            if (_rxIdx > 0) {
                _rxBuf[_rxIdx] = '\0';
                _rxIdx = 0;
                return true;  // Línea completa
            }
        } else {
            if (_rxIdx < RX_BUF_SIZE - 1) {
                _rxBuf[_rxIdx++] = c;
            } else {
                // Buffer overflow → descartar y reiniciar
                _rxIdx = 0;
            }
        }
    }
    return false;
}

bool SerialTransport::available() {
    return _readLine();
}

bool SerialTransport::readPacket(RFPacket& pkt) {
    // El buffer ya fue llenado por _readLine() dentro de available()
    // Parsear el JSON del buffer _rxBuf
    StaticJsonDocument<256> doc;
    DeserializationError err = deserializeJson(doc, _rxBuf);
    if (err) {
        sendStatus("JSON parse error");
        return false;
    }

    // Rellenar el paquete con los campos del JSON
    memset(&pkt, 0, sizeof(pkt));
    pkt.originId   = 0;                           // Siempre del master
    pkt.destId     = doc["dest"]  | (uint8_t)0xFF;
    pkt.deviceType = DEV_TYPE_GATEWAY;
    pkt.command    = doc["cmd"]   | (uint8_t)CMD_ON;

    // Leer array de data[] si está presente
    if (doc.containsKey("data")) {
        JsonArray arr = doc["data"].as<JsonArray>();
        uint8_t i = 0;
        for (JsonVariant v : arr) {
            if (i >= 26) break;
            pkt.data[i++] = v.as<uint8_t>();
        }
    }

    Protocol_seal(&pkt);
    return true;
}

bool SerialTransport::sendPacket(const RFPacket& pkt) {
    StaticJsonDocument<512> doc;
    doc["origin"] = pkt.originId;
    doc["dest"]   = pkt.destId;
    doc["type"]   = pkt.deviceType;
    doc["cmd"]    = pkt.command;

    JsonArray arr = doc.createNestedArray("data");
    for (uint8_t i = 0; i < 26; i++) {
        arr.add(pkt.data[i]);
    }

    serializeJson(doc, Serial);
    Serial.println();  // '\n' como terminador de línea
    return true;
}

bool SerialTransport::sendAck(bool ok, uint8_t destId) {
    StaticJsonDocument<64> doc;
    doc["ack"]  = ok;
    doc["dest"] = destId;
    serializeJson(doc, Serial);
    Serial.println();
    return true;
}

void SerialTransport::sendStatus(const char* msg) {
    if (!msg) return;
    if (msg[0] == '{') {
        Serial.println(msg);
    } else {
        StaticJsonDocument<128> doc;
        doc["log"] = msg;
        serializeJson(doc, Serial);
        Serial.println();
    }
}
