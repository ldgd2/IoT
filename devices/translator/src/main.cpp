#include <Arduino.h>
#include <SPI.h>
#include <RF24.h>
#include <ArduinoJson.h>
#include "../config/Protocol.h"
#include "../config/RadioConfig.h"

RF24 radio(CE_PIN, CSN_PIN);
const uint64_t rxAddress = 0x7878787878LL;
const uint64_t txAddress = 0xB3B4B5B6F1LL;

unsigned long lastHeartbeat = 0;

void setup() {
    Serial.begin(115200);
    while (!Serial) {} // Esperar Serial por USB
    
    if (!radio.begin()) {
        Serial.println("{\"error\": \"radio_hardware_not_responding\"}");
        while (1) {}
    }
    
    radio.setChannel(RF_CHANNEL);
    radio.setDataRate(RF_DATARATE);
    radio.setPALevel(RF24_PA_MAX);
    
    radio.openWritingPipe(txAddress);
    radio.openReadingPipe(1, rxAddress);
    radio.startListening();
    
    Serial.println("{\"status\": \"translator_ready\"}");
}

void loop() {
    // 1. Leer RF y convertir a JSON para Python (Gateway)
    if (radio.available()) {
        RFPacket packet;
        radio.read(&packet, sizeof(packet));
        
        StaticJsonDocument<256> doc;
        doc["origin"] = packet.originId;
        doc["dest"] = packet.destId;
        doc["type"] = packet.deviceType;
        doc["cmd"] = packet.command;
        
        JsonArray dataArray = doc.createNestedArray("data");
        for(int i=0; i<4; i++) dataArray.add(packet.data[i]);
        
        serializeJson(doc, Serial);
        Serial.println();
    }
    
    // 2. Leer JSON desde Python (Serial) y convertir a RF
    if (Serial.available()) {
        String input = Serial.readStringUntil('\n');
        StaticJsonDocument<256> doc;
        DeserializationError err = deserializeJson(doc, input);
        
        if (!err) {
            RFPacket packet;
            packet.originId = 0x01; // ID del Gateway
            packet.destId = doc["dest"] | 0xFF;
            packet.deviceType = DEV_TYPE_GATEWAY;
            packet.command = doc["cmd"] | CMD_ON;
            
            radio.stopListening();
            bool ok = radio.write(&packet, sizeof(packet));
            radio.startListening();
            
            StaticJsonDocument<128> ack;
            ack["ack"] = ok;
            serializeJson(ack, Serial);
            Serial.println();
        }
    }
    
    // 3. Heartbeat autonomo del Gateway cada 30s
    if (millis() - lastHeartbeat > 30000) {
        lastHeartbeat = millis();
        RFPacket hb;
        hb.originId = 0x01;
        hb.destId = 0xFF;
        hb.deviceType = DEV_TYPE_GATEWAY;
        hb.command = CMD_HEARTBEAT;
        
        radio.stopListening();
        radio.write(&hb, sizeof(hb));
        radio.startListening();
    }
}
