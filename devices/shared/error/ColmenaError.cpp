#include "ColmenaError.h"
#include "../display/ui/UILayout.h"
#include "../transport/ITransport.h"
#include <stddef.h>
#include <string.h>
#include <stdio.h>

UILayout*   ColmenaError::_registeredUI        = nullptr;
ITransport* ColmenaError::_registeredTransport = nullptr;
uint16_t    ColmenaError::_activeErrorCode     = 0;
uint32_t    ColmenaError::_activeErrorBits     = 0;
char        ColmenaError::_customDetailBuf[64] = {0};

static const ErrorInfo kColmenaErrorCatalog[] = {
    // ── Errores Básicos y de Red (1 - 99) ──────────────────────────────────
    { ERR_RF_LOW_SIGNAL,    "ERR_RF_LOW_SIGNAL",    "BAJA SENAL RF",        "La calidad del enlace con el nodo ha caido por debajo de -85dBm debido a distancia o abstaculos.", "Reubicar la antena RF exterior o acercar el nodo leaf hacia el gateway.", SEV_WARN },
    { ERR_NODE_OFFLINE,     "ERR_NODE_OFFLINE",     "NODO OFFLINE",         "Un dispositivo de la malla dejo de responder al latido de corazon en el tiempo limite.", "Verificar bateria, conexion de alimentacion y estado del nodo leaf.",  SEV_WARN },
    { ERR_PACKET_CORRUPT,   "ERR_PACKET_CORRUPT",   "PAQUETE CORRUPTO",     "El checksum CRC16 del paquete no coincide. Fuerte interferencia electromagnética o ruido RF.",  "Cambiar de canal RF en RadioConfig.h (ej: Canal 100) y alejar de routers Wi-Fi.", SEV_WARN },
    { ERR_MESH_RETRY,       "ERR_MESH_RETRY",       "REINTENTO DE RED",     "El nodo esta negociando dinamicamente una nueva direccion logica en la malla RF24Mesh.",  "Espera automatica de estabilizacion de red. No requiere accion manual.",      SEV_INFO },
    { ERR_TX_QUEUE_FULL,    "ERR_TX_QUEUE_FULL",    "COLA DE TRANSMISION",  "El buffer de salida del transceptor esta lleno. Descartando paquetes antiguos por congestion.",   "Reducir frecuencia de reportes en nodos leaf o aumentar datarate a 2Mbps.", SEV_WARN },
    { ERR_HUB_DISCONNECTED, "ERR_HUB_DISCONNECTED", "DESCONEXION HUB",      "Se perdio la comunicacion serial o USB HID con el servidor central / frontend.",    "Revisar cable USB conectando el YD-RP2040 y puerto COM en el servidor.",     SEV_WARN },
    { ERR_67,               "ERR_67",               "SESENTA Y SIETE",      "Detectada rafaga inusual de 6 o 7 paquetes corruptos o perdidos de forma consecutiva.", "Verificar antena del transceptor y evitar obstrucciones metalicas directas.", SEV_EASTER_EGG },

    // ── Errores de Hardware, Pines y Módulos (100 - 199) ───────────────────
    { ERR_RADIO_INIT_FAIL,  "ERR_RADIO_INIT_FAIL",  "FALLO INICIO RADIO",   "El microcontrolador no logro sincronizar con el chip nRF24L01+ via bus SPI en el arranque.",   "Verificar cableado fisico: SCK(18), MOSI(19), MISO(16), CE(14), CSN(15).", SEV_CRITICAL },
    { ERR_MEMORY_CORRUPT,   "ERR_MEMORY_CORRUPT",   "MEMORIA CORRUPTA",     "Fallo al validar integridad de parametros en Flash/EEPROM. Restaurando defaults de fabrica.", "Ejecutar comando de re-configuracion o re-flashear firmware limpio.", SEV_CRITICAL },
    { ERR_VOLTAGE_UNSTABLE, "ERR_VOLTAGE_UNSTABLE", "VOLTAJE INESTABLE",    "Caida drastica de tension en el rail de 3.3V durante picos de transmision de radio.",      "Anadir condensador electrolitico 10uF-100uF entre pines VCC y GND del radio.", SEV_CRITICAL },
    { ERR_LOW_RAM,          "ERR_LOW_RAM",          "MEMORIA RAM BAJA",     "Desbordamiento inminente del stack/heap en el microcontrolador YD-RP2040.",         "Reducir tamano de colas de paquetes o reiniciar el gateway.",  SEV_CRITICAL },
    { ERR_I2C_BUS_STUCK,    "ERR_I2C_BUS_STUCK",    "BUS I2C BLOQUEADO",    "El bus de datos de pantalla OLED o sensores no responde a impulsos de reloj.",           "Revisar resistencias Pull-Up de 4.7k y cables I2C en pines SDA/SCL.", SEV_CRITICAL },
    { ERR_PIN_SCK_FAULT,    "ERR_PIN_SCK_FAULT",    "FALLA PIN RELOJ SPI",  "Ausencia de senal de sincronizacion en el pin de reloj del bus SPI. Modulo aislado.",       "Inspeccionar soldadura y pista del Pin GP18 / SCK en el YD-RP2040.",        SEV_CRITICAL },
    { ERR_PIN_MOSI_FAULT,   "ERR_PIN_MOSI_FAULT",   "FALLA PIN DATOS OUT",  "El modulo de radio no reacciona a comandos emitidos por el maestro (MOSI cortado).",        "Inspeccionar soldadura y continuidad del Pin GP19 / MOSI.",       SEV_CRITICAL },
    { ERR_PIN_MISO_FAULT,   "ERR_PIN_MISO_FAULT",   "FALLA PIN DATOS IN",   "El microcontrolador no recibe datos de respuesta desde el modulo de radio (MISO cortado).", "Inspeccionar soldadura y continuidad del Pin GP16 / MISO.",    SEV_CRITICAL },
    { ERR_PIN_CE_CSN_FAULT, "ERR_PIN_CE_CSN_FAULT", "FALLA CONTROL RADIO",  "Los pines de activacion de chip (CE/CSN) no cambian de estado logico correctamente.",       "Verificar conexion fisica en pines GP14 (CE) y GP15 (CSN).",    SEV_CRITICAL },
    { ERR_OLED_NOT_DETECTED,"ERR_OLED_NOT_DETECTED","PANTALLA NO DETECTADA","No se detecto respuesta del modulo OLED SSD1306 en direcciones I2C 0x3C ni 0x3D.", "Verificar pines I2C (SDA/SCL) y alimentacion de 3.3V del display.", SEV_CRITICAL },

    // ── Easter Eggs y Errores Divertidos ───────────────────────────────────
    { ERR_404,              "ERR_404",              "ERROR 404 NODO",       "El nodo de destino (o el cafe del programador) ha desaparecido misteriosamente de la red.", "Revise que los nodos esten encendidos o sirvase una taza de cafe caliente.", SEV_EASTER_EGG },
    { ERR_418,              "ERR_418",              "SOY UNA TETERA?",      "Violacion del protocolo RFC 2324: El gateway intento preparar cafe en un transceptor RF.", "Conecte un dispositivo compatible o use una cafetera Wi-Fi autorizada.", SEV_EASTER_EGG },
    { ERR_666,              "ERR_666",              "INVASION DE ABEJAS",   "¡La Colmena ha cobrado conciencia propia! Enjambre cibernetico tomando el control del bus.", "Ofrezca un frasco de miel al YD-RP2040 en son de paz inmediata.", SEV_EASTER_EGG },
    { ERR_777,              "ERR_777",              "NOOO MIS PAQUETES",    "¡Tragedia en el aire! Un paquete critico sufrio combustion espontanea en la estratosfera RF.", "Asegurar conexion estable de 3.3V y mandar fuerzas al transceptor.", SEV_EASTER_EGG },
    { ERR_HOMERO,           "ERR_HOMERO",           "MIRA MARGE SOY BRAS.", "En algun lugar de la malla RF un nodo rebelde envio un payload con gemidos o audios.", "Ignorar con elegancia o reiniciar el nodo bromista en la red.", SEV_EASTER_EGG },
    { ERR_PD,               "ERR_PD",               "POBRE DOG / PERRO",    "Un nodo se esta pasando de listo enviando paquetes incompletos o burlando la seguridad.", "Inspeccionar el firmware del nodo leaf y castigar al responsable.", SEV_EASTER_EGG },
    { ERR_999,              "ERR_999",              "PARPADEO FUERTE",      "El usuario miro fijamente al microcontrolador e intimido a los sensibles transistores.", "Parpadear suavemente y sonreir para relajar los chips del YD-RP2040.", SEV_EASTER_EGG }
};

void ColmenaError::registerUI(UILayout* ui) {
    _registeredUI = ui;
}

void ColmenaError::registerTransport(ITransport* transport) {
    _registeredTransport = transport;
}

void ColmenaError::raise(uint16_t code, const char* customDetail) {
    _activeErrorCode = code;
    
    // Almacenamiento bitwise compacto para consumo mínimo de RAM en RP2040
    if (code < 32) {
        _activeErrorBits |= (1UL << code);
    } else {
        _activeErrorBits |= (1UL << 31); // Bit de error extendido/especial
    }

    if (customDetail) {
        strncpy(_customDetailBuf, customDetail, sizeof(_customDetailBuf) - 1);
        _customDetailBuf[sizeof(_customDetailBuf) - 1] = '\0';
    } else {
        _customDetailBuf[0] = '\0';
    }
    
    const ErrorInfo* info = get(code);

    // 1. Notificar al frontend/HUB via transporte (para que el usuario pueda aceptarlo en la PC)
    if (_registeredTransport != nullptr && info != nullptr) {
        char jsonBuf[256];
        const char* detailStr = (customDetail && customDetail[0]) ? customDetail : info->detail;
        const char* fixStr = info->suggestedFix ? info->suggestedFix : "";
        snprintf(jsonBuf, sizeof(jsonBuf),
                 "{\"event\":\"sys_error\",\"code\":%u,\"name\":\"%s\",\"title\":\"%s\",\"detail\":\"%s\",\"fix\":\"%s\",\"sev\":%u}",
                 info->code, info->name, info->title, detailStr, fixStr, (unsigned int)info->severity);
        _registeredTransport->sendStatus(jsonBuf);
    }

    // 2. Si hay un graficador registrado, ¡salta directamente a mostrar el error en pantalla!
    if (_registeredUI != nullptr) {
        if (customDetail && customDetail[0]) {
            _registeredUI->drawSystemErrorCustom(code, customDetail);
        } else {
            _registeredUI->drawSystemError(code);
        }
    }
}

void ColmenaError::acknowledge(uint16_t code) {
    // Al ser aceptado desde el frontend, limpiamos el error para que ya no salga en el display
    if (code == 0 || code == _activeErrorCode) {
        _activeErrorCode = 0;
        _activeErrorBits = 0;
        _customDetailBuf[0] = '\0';
    }
}

void ColmenaError::renderActiveError(uint8_t animFrame) {
    if (_activeErrorCode == 0 || _registeredUI == nullptr) return;
    
    const ErrorInfo* info = get(_activeErrorCode);
    if (info) {
        // Llama a la animación en tiempo real del error sobre la pantalla OLED
        _registeredUI->drawAnimatedError(info, animFrame);
    }
}

void ColmenaError::clear() {
    _activeErrorCode = 0;
    _activeErrorBits = 0;
    _customDetailBuf[0] = '\0';
}

bool ColmenaError::hasActiveError() {
    return _activeErrorCode != 0;
}

uint16_t ColmenaError::getActiveErrorCode() {
    return _activeErrorCode;
}

uint32_t ColmenaError::getActiveErrorBits() {
    return _activeErrorBits;
}

const ErrorInfo* ColmenaError::get(uint16_t code) {
    for (size_t i = 0; i < sizeof(kColmenaErrorCatalog) / sizeof(kColmenaErrorCatalog[0]); i++) {
        if (kColmenaErrorCatalog[i].code == code) {
            return &kColmenaErrorCatalog[i];
        }
    }
    return nullptr;
}

const ErrorInfo* ColmenaError::getByName(const char* name) {
    if (!name) return nullptr;
    for (size_t i = 0; i < sizeof(kColmenaErrorCatalog) / sizeof(kColmenaErrorCatalog[0]); i++) {
        if (strcmp(kColmenaErrorCatalog[i].name, name) == 0) {
            return &kColmenaErrorCatalog[i];
        }
    }
    return nullptr;
}
