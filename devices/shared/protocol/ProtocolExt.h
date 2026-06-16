#ifndef PROTOCOL_EXT_H
#define PROTOCOL_EXT_H

/**
 * @file ProtocolExt.h
 * @brief Extensiones del protocolo por tipo de dispositivo.
 *
 * El campo data[26] del RFPacket tiene semántica diferente según el
 * comando y el tipo de dispositivo que lo emite. Este archivo define
 * helpers estáticos para leer y escribir ese campo con significado específico,
 * manteniendo compatibilidad con la estructura base RFPacket.
 *
 * Cada dispositivo incluye SOLO el helper que necesita, o todos si quiere
 * poder interpretar paquetes de otros dispositivos (ej: el gateway).
 *
 * Compartido entre todos los dispositivos.
 */

#include "Protocol.h"
#include <string.h>

// ─────────────────────────────────────────────────────────────────────────────
// Layout del campo data[] para CMD_DISCOVER
// ─────────────────────────────────────────────────────────────────────────────
// data[0]      = longitud del nombre del nodo (N bytes, max 15)
// data[1..N]   = nombre del nodo en ASCII
// data[16]     = Feature Flags (bitmask FEATURE_*)
// data[17]     = versión de firmware (BCD: 0x12 = v1.2)
// data[18..25] = reservado

// ─────────────────────────────────────────────────────────────────────────────
// Layout del campo data[] para CMD_HEARTBEAT (nodo light)
// ─────────────────────────────────────────────────────────────────────────────
// data[0] = estado del relay (0=OFF, 1=ON)
// data[1] = nivel de brillo (0-255, 0 si no aplica)
// data[2..25] = reservado

// ─────────────────────────────────────────────────────────────────────────────
// Layout del campo data[] para CMD_CONFIG_SYNC (enviado por gateway)
// ─────────────────────────────────────────────────────────────────────────────
// data[0]    = canal RF
// data[1]    = datarate (0=250k, 1=1M, 2=2M)
// data[2]    = heartbeat interval en segundos (0-255, 0=usar default)
// data[3..7] = nombre de la colmena (5 bytes ASCII)
// data[8..25] = reservado


// ─────────────────────────────────────────────────────────────────────────────
// Helper: Payloads de Nodo Light
// ─────────────────────────────────────────────────────────────────────────────

struct LightPayload {

    /**
     * @brief Escribe el payload de descubrimiento en data[].
     * @param pkt       Paquete a rellenar (command debe ser CMD_DISCOVER)
     * @param name      Nombre del nodo (max 15 chars)
     * @param features  Bitmask de features (FEATURE_RELAY | FEATURE_BRIGHTNESS, etc.)
     * @param fwVersion Versión firmware en BCD (ej: 0x10 = v1.0)
     */
    static void setDiscovery(RFPacket& pkt, const char* name,
                              uint8_t features, uint8_t fwVersion = 0x10) {
        uint8_t len = 0;
        while (name[len] && len < 15) len++;
        pkt.data[0] = len;
        for (uint8_t i = 0; i < len; i++) pkt.data[i + 1] = (uint8_t)name[i];
        pkt.data[16] = features;
        pkt.data[17] = fwVersion;
    }

    /**
     * @brief Escribe el payload de heartbeat en data[].
     * @param pkt         Paquete a rellenar (command debe ser CMD_HEARTBEAT)
     * @param relayOn     Estado actual del relay
     * @param brightness  Nivel de brillo actual (0 si no aplica)
     */
    static void setHeartbeat(RFPacket& pkt, bool relayOn, uint8_t brightness = 0) {
        pkt.data[0] = relayOn ? 1 : 0;
        pkt.data[1] = brightness;
    }

    /**
     * @brief Lee el estado de relay de un paquete CMD_HEARTBEAT.
     */
    static bool getHeartbeatRelay(const RFPacket& pkt) {
        return pkt.data[0] != 0;
    }

    /**
     * @brief Lee el nivel de brillo de un paquete CMD_HEARTBEAT.
     */
    static uint8_t getHeartbeatBrightness(const RFPacket& pkt) {
        return pkt.data[1];
    }
};


// ─────────────────────────────────────────────────────────────────────────────
// Helper: Payloads de Gateway/Translator
// ─────────────────────────────────────────────────────────────────────────────

struct GatewayPayload {

    /**
     * @brief Lee el nombre del nodo de un paquete CMD_DISCOVER.
     * @param pkt   Paquete de descubrimiento recibido
     * @param buf   Buffer donde escribir el nombre (null-terminated)
     * @param bufLen Tamaño del buffer (min 17)
     */
    static void getDiscoverName(const RFPacket& pkt, char* buf, uint8_t bufLen) {
        uint8_t len = pkt.data[0];
        if (len >= bufLen) len = bufLen - 1;
        for (uint8_t i = 0; i < len; i++) buf[i] = (char)pkt.data[i + 1];
        buf[len] = '\0';
    }

    /**
     * @brief Lee los feature flags de un paquete CMD_DISCOVER.
     */
    static uint8_t getDiscoverFeatures(const RFPacket& pkt) {
        return pkt.data[16];
    }

    /**
     * @brief Escribe el payload de sincronización de colmena en data[].
     * @param pkt              Paquete a rellenar (command debe ser CMD_CONFIG_SYNC)
     * @param rfChannel        Canal RF de la colmena
     * @param rfDataRate       Datarate (0=250kbps, 1=1Mbps, 2=2Mbps)
     * @param heartbeatSecs    Intervalo de heartbeat en segundos
     * @param colmenaName      Nombre de la colmena (max 5 chars)
     */
    static void setConfigSync(RFPacket& pkt, uint8_t rfChannel, uint8_t rfDataRate,
                               uint8_t heartbeatSecs, const char* colmenaName) {
        pkt.data[0] = rfChannel;
        pkt.data[1] = rfDataRate;
        pkt.data[2] = heartbeatSecs;
        for (uint8_t i = 0; i < 5 && colmenaName[i]; i++) {
            pkt.data[3 + i] = (uint8_t)colmenaName[i];
        }
    }

    /**
     * @brief Lee los parámetros de sincronización de colmena desde data[].
     */
    static uint8_t getConfigChannel(const RFPacket& pkt)     { return pkt.data[0]; }
    static uint8_t getConfigDataRate(const RFPacket& pkt)    { return pkt.data[1]; }
    static uint8_t getConfigHeartbeat(const RFPacket& pkt)   { return pkt.data[2]; }
    static void    getConfigName(const RFPacket& pkt, char* buf, uint8_t bufLen) {
        uint8_t len = (bufLen < 6) ? bufLen - 1 : 5;
        for (uint8_t i = 0; i < len; i++) buf[i] = (char)pkt.data[3 + i];
        buf[len] = '\0';
    }
};


// ─────────────────────────────────────────────────────────────────────────────
// Helper: Payloads de Sensor (extensible a futuro)
// ─────────────────────────────────────────────────────────────────────────────

struct SensorPayload {

    /**
     * @brief Layout CMD_HEARTBEAT para sensor de temperatura/humedad:
     * data[0..1] = temperatura en centésimas de °C (int16_t, big-endian)
     *              Ej: 2350 = 23.50 °C
     * data[2..3] = humedad en centésimas de % (uint16_t, big-endian)
     *              Ej: 6075 = 60.75 %
     */
    static void setTempHumidity(RFPacket& pkt, int16_t tempCenti, uint16_t humCenti) {
        pkt.data[0] = (uint8_t)((tempCenti >> 8) & 0xFF);
        pkt.data[1] = (uint8_t)(tempCenti & 0xFF);
        pkt.data[2] = (uint8_t)((humCenti >> 8) & 0xFF);
        pkt.data[3] = (uint8_t)(humCenti & 0xFF);
    }

    static int16_t  getTemperature(const RFPacket& pkt) {
        return (int16_t)((pkt.data[0] << 8) | pkt.data[1]);
    }
    static uint16_t getHumidity(const RFPacket& pkt) {
        return (uint16_t)((pkt.data[2] << 8) | pkt.data[3]);
    }
};

#endif // PROTOCOL_EXT_H
