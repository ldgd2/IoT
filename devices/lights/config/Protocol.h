#ifndef PROTOCOL_H
#define PROTOCOL_H

#include <stdint.h>

#define CMD_ON 0x01
#define CMD_OFF 0x02
#define CMD_REPORT 0x03
#define CMD_HEARTBEAT 0x04
#define CMD_DISCOVER 0x05

#define DEV_TYPE_GATEWAY 0x01
#define DEV_TYPE_LIGHT   0x02
#define DEV_TYPE_SENSOR  0x03

// Feature Flags (Bitmask)
#define FEATURE_RELAY       0x01  // ON/OFF capabilities
#define FEATURE_BRIGHTNESS  0x02  // PWM/Brightness capabilities
#define FEATURE_TEMP        0x04  // Temperature sensor
#define FEATURE_HUMIDITY    0x08  // Humidity sensor

// Carga máxima de nRF24L01 es 32 bytes
struct __attribute__((packed)) RFPacket {
    // Header (3 bytes)
    uint8_t originId;
    uint8_t destId;      // 0xFF = Broadcast
    uint8_t deviceType;  
    
    // Body (29 bytes)
    uint8_t command;     
    uint8_t data[26];    
    uint16_t checksum;   
};

#endif
