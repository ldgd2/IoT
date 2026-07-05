#ifndef COLMENA_ERROR_H
#define COLMENA_ERROR_H

#include <stdint.h>

// Forward declarations para no depender de cabeceras pesadas en microcontroladores
class UILayout;
class ITransport;

// Máscaras Bitwise / Binarias para ultra-bajo consumo de recursos en el RP2040
#define COLMENA_ERR_SEV_MASK      0xC000
#define COLMENA_ERR_MOD_MASK      0x3F00
#define COLMENA_ERR_ID_MASK       0x00FF

enum ErrorSeverity {
    SEV_INFO       = 0x0000,
    SEV_WARN       = 0x4000,
    SEV_CRITICAL   = 0x8000,
    SEV_EASTER_EGG = 0xC000
};

// Códigos de error estandarizados y Easter Eggs del ecosistema Colmena
enum ColmenaErrorCode : uint16_t {
    // ── Errores Básicos y de Red (1 - 99) ──────────────────────────────────
    ERR_RF_LOW_SIGNAL          = 1,
    ERR_NODE_OFFLINE           = 2,
    ERR_PACKET_CORRUPT         = 3,
    ERR_MESH_RETRY             = 4,
    ERR_TX_QUEUE_FULL          = 5,
    ERR_HUB_DISCONNECTED       = 10,
    ERR_67                     = 67,  // Easter egg: 6 o 7 paquetes corruptos

    // ── Errores de Hardware, Pines y Módulos (100 - 199) ───────────────────
    ERR_RADIO_INIT_FAIL        = 101, // nRF24L01+ no responde por SPI
    ERR_MEMORY_CORRUPT         = 102, // Flash / EEPROM corrupta o vacía
    ERR_VOLTAGE_UNSTABLE       = 103, // Caída de tensión en raíl 3.3V
    ERR_LOW_RAM                = 104, // Desbordamiento de memoria RAM
    ERR_I2C_BUS_STUCK          = 105, // Bus I2C / Pantalla OLED no responde
    ERR_PIN_SCK_FAULT          = 110, // Falla en pin de reloj SPI (GP18)
    ERR_PIN_MOSI_FAULT         = 111, // Falla en pin MOSI (GP19)
    ERR_PIN_MISO_FAULT         = 112, // Falla en pin MISO (GP16)
    ERR_PIN_CE_CSN_FAULT       = 113, // Falla en pines de control radio (GP14/GP15)
    ERR_OLED_NOT_DETECTED      = 115, // Módulo SSD1306 no detectado en I2C

    // ── Easter Eggs y Errores Divertidos ───────────────────────────────────
    ERR_404                    = 404,
    ERR_EASTER_COFFEE_404      = 404,
    ERR_418                    = 418,
    ERR_EASTER_TEAPOT_418      = 418,
    ERR_666                    = 666,
    ERR_EASTER_BEES_666        = 666,
    ERR_777                    = 777,
    ERR_EASTER_JACKPOT_777     = 777,
    ERR_HOMERO                 = 808,
    ERR_PD                     = 909,
    ERR_999                    = 999,
    ERR_EASTER_BLINK_999       = 999
};

struct ErrorInfo {
    uint16_t      code;
    const char*   name;
    const char*   title;
    const char*   detail;
    const char*   suggestedFix; // Sugerencia técnica de solución o acción recomendada
    ErrorSeverity severity;
};

class ColmenaError {
public:
    /**
     * @brief Registra el motor de interfaz gráfica (UILayout) para renderizar errores.
     */
    static void registerUI(UILayout* ui);

    /**
     * @brief Registra el canal de transporte (ITransport) para enviar eventos JSON al frontend.
     */
    static void registerTransport(ITransport* transport);

    /**
     * @brief Dispara un error de forma inmediata en todo el sistema.
     * Guarda en registro bitwise, muestra en pantalla y envía JSON al frontend.
     */
    static void raise(uint16_t code, const char* customDetail = nullptr);

    /**
     * @brief Acepta / Reconoce (Acknowledge) un error desde el frontend o usuario.
     * Limpia el estado bitwise y quita la pantalla de error para seguir operando normalmente.
     */
    static void acknowledge(uint16_t code = 0);

    /**
     * @brief Dibuja la animación en tiempo real del error activo (llamar en loop).
     */
    static void renderActiveError(uint8_t animFrame);

    /** @brief Limpia el estado del error activo. */
    static void clear();

    /** @brief Devuelve true si hay cualquier error activo en el sistema. */
    static bool hasActiveError();

    /** @brief Devuelve el código del error principal activo. */
    static uint16_t getActiveErrorCode();

    /** @brief Devuelve la máscara bitwise de errores activos. */
    static uint32_t getActiveErrorBits();

    /** @brief Consulta información completa de un error por código. */
    static const ErrorInfo* get(uint16_t code);

    /** @brief Consulta información de un error por nombre. */
    static const ErrorInfo* getByName(const char* name);

private:
    static UILayout*   _registeredUI;
    static ITransport* _registeredTransport;
    static uint16_t    _activeErrorCode;
    static uint32_t    _activeErrorBits;
    static char        _customDetailBuf[64];
};

#endif // COLMENA_ERROR_H
