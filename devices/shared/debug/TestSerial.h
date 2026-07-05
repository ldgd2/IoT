#ifndef TEST_SERIAL_H
#define TEST_SERIAL_H

/**
 * @file TestSerial.h (shared/debug)
 * @brief Clase modular para diagnóstico, inspección de paquetes RF y emparejamiento por puerto Serial USB.
 *
 * Esta clase encapsula toda la lógica de monitoreo e interacción por puerto serial (USB/COM)
 * en los microcontroladores (RP2040, ESP32, ESP8266, Arduino).
 *
 * Al estar aislada en esta clase, se puede instanciar en `setup()` y `loop()` durante el
 * desarrollo o pruebas de emparejamiento, y eliminarse/comentarse fácilmente en producción
 * para mantener el código principal 100% limpio y ligero.
 */

#include <Arduino.h>
#include "../protocol/Protocol.h"
#include "../colmena/ColmenaNode.h"
#include "../actuators/relay/RelayBank.h"

class TestSerial {
public:
    TestSerial() {}

    /**
     * @brief Inicializa el puerto Serial para diagnóstico y emparejamiento.
     * @param baud Velocidad en baudios (por defecto 115200)
     */
    void init(unsigned long baud = 115200) {
        Serial.begin(baud);
        // Pequeño retardo para dar tiempo a que puertos USB nativos (RP2040) conecten
        delay(300);
        Serial.println("\n=======================================================");
        Serial.println("🐞 [TEST SERIAL] Módulo de Diagnóstico Colmena Activo");
        Serial.println("Comandos disponibles por USB:");
        Serial.println("  PAIR / DISCOVER -> Envia paquete de emparejamiento RF");
        Serial.println("  STATUS          -> Muestra estado interno y relays");
        Serial.println("  ON / OFF        -> Prueba local de relays");
        Serial.println("=======================================================\n");
    }

    /**
     * @brief Registra en consola cuando el nodo recibe un paquete por radiofrecuencia (RF).
     */
    void logPacketRX(const RFPacket& pkt) {
        Serial.print("📥 [RX RF] Cmd: 0x");
        if (pkt.command < 16) Serial.print("0");
        Serial.print(pkt.command, HEX);
        Serial.print(" | Origin: "); Serial.print(pkt.originId);
        Serial.print(" | Dest: "); Serial.print(pkt.destId);
        Serial.print(" | Data[0]: "); Serial.println(pkt.data[0]);
    }

    /**
     * @brief Registra en consola cuando el nodo envía un anuncio o reporte por radiofrecuencia.
     */
    void logPacketTX(const char* action) {
        Serial.print("📤 [TX RF] Enviando trama: ");
        Serial.println(action);
    }

    /**
     * @brief Escucha y procesa comandos entrantes por el puerto USB Serial.
     * Debe ser llamado periódicamente dentro de `loop()`.
     */
    void update(ColmenaNode& colmena, RelayBank& relays, const char* nodeName, uint8_t nodeId) {
        while (Serial.available() > 0) {
            char c = Serial.read();
            if (c == '\r') continue;
            if (c == '\n') {
                _rxBuf.trim();
                _rxBuf.toUpperCase();

                if (_rxBuf.length() > 0) {
                    if (_rxBuf == "PAIR" || _rxBuf == "DISCOVER" || _rxBuf == "ANNOUNCE") {
                        Serial.println("\n=================================================");
                        Serial.println("⚡ [TEST SERIAL] Orden de emparejamiento (PAIR) recibida.");
                        Serial.println("📡 Enviando trama de anuncio (CMD_DISCOVER) por RF...");
                        colmena.announce(nodeName);
                        Serial.println("✔️ [TEST SERIAL] Paquete de anuncio RF transmitido.");
                        Serial.println("=================================================\n");

                    } else if (_rxBuf == "STATUS") {
                        Serial.println("\n--- ℹ️ DIAGNÓSTICO DEL NODO ---");
                        Serial.print("Nombre:       "); Serial.println(nodeName);
                        Serial.print("ID de Nodo:   "); Serial.println(nodeId);
                        Serial.print("Relays Mask:  0b"); Serial.println(relays.getMask(), BIN);
                        Serial.print("Uptime (s):   "); Serial.println(millis() / 1000);
                        Serial.println("---------------------------------\n");

                    } else if (_rxBuf == "ON") {
                        Serial.println("💡 [TEST SERIAL PRUEBA LOCAL] Encendiendo relés localmente...");
                        relays.setAll(true);

                    } else if (_rxBuf == "OFF") {
                        Serial.println("🌑 [TEST SERIAL PRUEBA LOCAL] Apagando relés localmente...");
                        relays.setAll(false);

                    } else if (_rxBuf == "HELP" || _rxBuf == "?") {
                        Serial.println("Comandos soportados: PAIR, STATUS, ON, OFF");

                    } else {
                        Serial.print("⚠️ Comando no reconocido: "); Serial.println(_rxBuf);
                    }
                }
                _rxBuf = "";
            } else {
                if (_rxBuf.length() < 64) _rxBuf += c;
            }
        }
    }

private:
    String _rxBuf = "";
};

#endif // TEST_SERIAL_H
