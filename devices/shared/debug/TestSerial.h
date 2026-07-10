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

    typedef void (*PairCallback)();

    void setPairCallback(PairCallback cb) {
        _pairCallback = cb;
    }

    /**
     * @brief Imprime en el puerto COM el diagnóstico detallado del módulo de radiofrecuencia.
     */
    void printRfDiagnostics(bool chipConnected) {
        Serial.println("\n--- 📡 DIAGNÓSTICO DE RADIO RF24 ---");
        if (chipConnected) {
            Serial.println("✔️ CHIP NRF24L01: CONECTADO Y FUNCIONANDO OK");
        } else {
            Serial.println("❌ ERROR FATAL DE RADIO FRECUENCIA: CHIP NRF24 NO RESPONDE");
            Serial.println("  [Causas probables y soluciones]:");
            Serial.println("  1. Voltaje/Ruido: Poner condensador de 10uF-100uF entre VCC y GND del nRF24");
            Serial.println("  2. Alimentación: Debe estar a 3.3V (¡NUNCA a 5V ni VBUS o se quema!)");
            Serial.println("  3. Cableado SPI en RP2040: CE=14, CSN=15, SCK=18, MOSI=19, MISO=16");
            Serial.println("  4. Módulo dañado: Si tocó 5V o se invirtió polaridad, el chip se daña.");
        }
        Serial.println("------------------------------------\n");
    }

    /**
     * @brief Escucha y procesa comandos entrantes por el puerto USB Serial.
     * Debe ser llamado periódicamente dentro de `loop()`.
     */
    void update(ColmenaNode& colmena, RelayBank& relays, bool rfChipConnected, const char* nodeName, uint8_t nodeId) {
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
                        Serial.println("📡 Iniciando ventana de búsqueda de 50 segundos por RF...");
                        colmena.startPairingWindow(nodeName);
                        if (_pairCallback) {
                            _pairCallback();
                        }
                        Serial.println("✔️ [TEST SERIAL] Ventana de vinculación (50s) activada en el nodo.");
                        Serial.println("=================================================\n");

                    } else if (_rxBuf == "STATUS" || _rxBuf == "RF" || _rxBuf == "RADIO") {
                        Serial.println("\n--- ℹ️ DIAGNÓSTICO DEL NODO ---");
                        Serial.print("Nombre:       "); Serial.println(nodeName);
                        Serial.print("ID de Nodo:   "); Serial.println(nodeId);
                        Serial.print("Relays Mask:  0b"); Serial.println(relays.getMask(), BIN);
                        Serial.print("Uptime (s):   "); Serial.println(millis() / 1000);
                        Serial.print("Estado GPIO 3:"); Serial.println(digitalRead(3) == HIGH ? " HIGH (3.3V - Tocado)" : " LOW (0V - Reposo/GND)");
                        printRfDiagnostics(rfChipConnected);

                    } else if (_rxBuf == "BUTTON" || _rxBuf == "BOTON" || _rxBuf == "PIN" || _rxBuf == "TTP223") {
                        Serial.println("\n--- 🔍 DIAGNÓSTICO EN TIEMPO REAL DEL BOTÓN Y ESCANEO DE PINES ---");
                        Serial.println("Pin configurado en código para el botón: GPIO 3");
                        Serial.print("⚡ Lectura actual en GPIO 3: ");
                        if (digitalRead(3) == HIGH) {
                            Serial.println("HIGH (3.3V/3.9V) ➔ ¡SEÑAL DETECTADA CORRECTAMENTE EN GPIO 3!");
                        } else {
                            Serial.println("LOW (0V) ➔ EN REPOSO O NO CONECTADO A ESTE GPIO");
                        }
                        Serial.println("\n📡 ESCANEANDO TODOS LOS PINES GPIO DE LA PLACA...");
                        Serial.print("👉 Pines que están recibiendo voltaje (HIGH) en este instante: ");
                        bool found = false;
                        for (int p = 0; p <= 28; p++) {
                            // Omitir pines SPI del radio para no generar lecturas falsas (14, 15, 16, 18, 19)
                            if (p == 14 || p == 15 || p == 16 || p == 18 || p == 19 || p == 23 || p == 24 || p == 25) continue;
                            if (digitalRead(p) == HIGH) {
                                Serial.print("[GPIO "); Serial.print(p); Serial.print("] ");
                                found = true;
                            }
                        }
                        if (!found) {
                            Serial.print("NINGUNO (Todos los GPIOs de usuario están en 0V)");
                        }
                        Serial.println("\n----------------------------------------------------------------\n");

                    } else if (_rxBuf == "ON") {
                        Serial.println("💡 [TEST SERIAL PRUEBA LOCAL] Encendiendo relés localmente...");
                        relays.setAll(true);

                    } else if (_rxBuf == "OFF") {
                        Serial.println("🌑 [TEST SERIAL PRUEBA LOCAL] Apagando relés localmente...");
                        relays.setAll(false);

                    } else if (_rxBuf == "HELP" || _rxBuf == "?") {
                        Serial.println("Comandos soportados: PAIR, STATUS, BUTTON, RF, ON, OFF");

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
    PairCallback _pairCallback = nullptr;
};

#endif // TEST_SERIAL_H
