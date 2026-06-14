#include <Arduino.h>
#include <SPI.h>
#include <RF24.h>
#include "../config/Protocol.h"
#include "../config/RadioConfig.h"

RF24 radio(CE_PIN, CSN_PIN);
const uint64_t rxAddress = 0xB3B4B5B6F1LL;
const uint64_t txAddress = 0x7878787878LL;

#define MY_NODE_ID 0x02

void setup() {
    Serial.begin(115200);
    
    if (!radio.begin()) {
        Serial.println("Error de Hardware NRF24");
        while (1) {}
    }
    
    radio.setChannel(RF_CHANNEL);
    radio.setDataRate(RF_DATARATE);
    radio.setPALevel(RF24_PA_MAX);
    
    radio.openWritingPipe(txAddress);
    radio.openReadingPipe(1, rxAddress);
    radio.startListening();
    
    Serial.println("Nodo de Luz Listo");
}

void loop() {
    // Escuchar comandos de RF en la colmena
    if (radio.available()) {
        RFPacket packet;
        radio.read(&packet, sizeof(packet));
        
        if (packet.destId == MY_NODE_ID || packet.destId == 0xFF) {
            Serial.print("Paquete RF recibido. Comando: ");
            Serial.println(packet.command);
            
            if (packet.command == CMD_ON) {
                // Aca activariamos el Relé/Triac
                Serial.println(">> LUZ ENCENDIDA");
            } else if (packet.command == CMD_OFF) {
                // Aca desactivariamos el Relé
                Serial.println(">> LUZ APAGADA");
            } else if (packet.command == CMD_HEARTBEAT) {
                // Ping del Gateway
                Serial.println(">> Heartbeat del Gateway detectado, red estable.");
            }
        }
    }
}
