#include <Arduino.h>
#include <SPI.h>
#include <RF24.h>
#include <RF24Network.h>
#include <RF24Mesh.h>
#include "../config/Protocol.h"
#include "../config/RadioConfig.h"

// Inicialización de la red Mesh
RF24 radio(CE_PIN, CSN_PIN);
RF24Network network(radio);
RF24Mesh mesh(radio, network);

// Este es el Node ID de esta luz específica (1 a 255)
// Para propósitos de este ejemplo es 1, pero cada placa debe tener uno único.
#define NODE_ID 1

const int RELAY_PIN = 5; 
unsigned long lastHeartbeat = 0;
bool relayState = false;

void setup() {
    Serial.begin(115200);
    pinMode(RELAY_PIN, OUTPUT);
    digitalWrite(RELAY_PIN, LOW);
    
    // Configurar Node ID y empezar Mesh
    mesh.setNodeID(NODE_ID);
    
    Serial.println("Conectando a la red Mesh...");
    if (!mesh.begin()) {
        Serial.println("Error iniciando radio SPI.");
        while(1){}
    }
    
    radio.setPALevel(RF24_PA_MAX);
    radio.setDataRate(RF_DATARATE);
    
    Serial.println("Conectado! Node ID: " + String(NODE_ID));
    
    // Enviar paquete de auto-descubrimiento
    RFPacket discover_pkt;
    discover_pkt.originId = NODE_ID;
    discover_pkt.destId = 0; // Master
    discover_pkt.deviceType = DEV_TYPE_LIGHT;
    discover_pkt.command = CMD_DISCOVER;
    
    String nodeName = "Luz Node " + String(NODE_ID);
    discover_pkt.data[0] = nodeName.length();
    for (int i = 0; i < nodeName.length() && i < 15; i++) {
        discover_pkt.data[i+1] = nodeName[i];
    }
    // Set Feature Flags (Bitmask: Relay + Brightness)
    discover_pkt.data[16] = FEATURE_RELAY | FEATURE_BRIGHTNESS;
    
    Serial.print("Tx Discovery... ");
    if (!mesh.write(&discover_pkt, 'C', sizeof(discover_pkt), 0)) {
        Serial.println("FAIL");
    } else {
        Serial.println("OK");
    }
}

void loop() {
    // 1. Mantener conexión con la red Mesh (Renovar DHCP si perdemos conexión)
    mesh.update();
    
    if (!mesh.checkConnection()) {
        Serial.println("Conexion perdida, renovando direccion...");
        mesh.renewAddress();
    }
    
    // 2. Leer comandos entrantes
    if (network.available()) {
        RF24NetworkHeader header;
        RFPacket packet;
        network.read(header, &packet, sizeof(packet));
        
        Serial.print("Rx Cmd: ");
        Serial.print(packet.command);
        Serial.print(" from: ");
        Serial.println(mesh.getNodeID(header.from_node));
        
        // Ejecutar comando
        if (packet.command == CMD_ON) {
            relayState = true;
            digitalWrite(RELAY_PIN, HIGH);
        } else if (packet.command == CMD_OFF) {
            relayState = false;
            digitalWrite(RELAY_PIN, LOW);
        } else if (packet.command == CMD_TOGGLE) {
            relayState = !relayState;
            digitalWrite(RELAY_PIN, relayState ? HIGH : LOW);
        }
    }
    
    // 3. Heartbeat cada 60s hacia el Master (Node ID 0)
    if (millis() - lastHeartbeat > 60000) {
        lastHeartbeat = millis();
        RFPacket hb;
        hb.originId = NODE_ID;
        hb.destId = 0; // Master
        hb.deviceType = DEV_TYPE_LIGHT;
        hb.command = CMD_HEARTBEAT;
        hb.data[0] = relayState ? 1 : 0; // Enviar estado actual en el heartbeat
        
        Serial.print("Tx Heartbeat... ");
        if (!mesh.write(&hb, 'C', sizeof(hb), 0)) {
            Serial.println("Fallo al enviar heartbeat. Verificando conexion...");
            if (!mesh.checkConnection()) {
                mesh.renewAddress();
            }
        } else {
            Serial.println("OK");
        }
    }
}
