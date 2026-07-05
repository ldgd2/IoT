#!/usr/bin/env python3
# ==============================================================================
# test_serial.py — Interfaz Gráfica Qt6 para Pruebas y Emparejamiento Serial
# ==============================================================================
# Clase modular TestSerial que gestiona interfaz gráfica PyQt6 con monitoreo
# en tiempo real por hilo independiente (QThread) y envío de comandos.
# ==============================================================================

import sys
import time
from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QComboBox, QPushButton, QLabel, QTextEdit, QLineEdit, QGroupBox,
    QMessageBox, QSplitter
)
from PyQt6.QtCore import Qt, QThread, pyqtSignal, QTimer
from PyQt6.QtGui import QFont, QColor, QTextCursor

try:
    import serial
    import serial.tools.list_ports
except ImportError:
    serial = None


class SerialReaderThread(QThread):
    """Hilo en segundo plano para leer datos del puerto serial sin congelar la UI"""
    data_received = pyqtSignal(str)
    error_occurred = pyqtSignal(str)

    def __init__(self, serial_conn):
        super().__init__()
        self.serial_conn = serial_conn
        self.running = True

    def run(self):
        while self.running and self.serial_conn and self.serial_conn.is_open:
            try:
                if self.serial_conn.in_waiting > 0:
                    line = self.serial_conn.readline().decode("utf-8", errors="replace").strip()
                    if line:
                        self.data_received.emit(line)
                else:
                    self.msleep(30)
            except Exception as e:
                if self.running:
                    self.error_occurred.emit(str(e))
                break

    def stop(self):
        self.running = False
        self.wait(500)


class TestSerial(QMainWindow):
    """
    Ventana Principal TestSerial:
    Proporciona control total del puerto serial del nodo (RP2040 / ESP / Arduino)
    para emparejar, consultar estado y monitorear respuestas en vivo.
    """
    def __init__(self):
        super().__init__()
        self.setWindowTitle("🐝 Colmena TestSerial — Diagnóstico y Emparejamiento por USB (Qt6)")
        self.resize(850, 600)
        self.serial_conn = None
        self.reader_thread = None

        self._apply_dark_style()
        self._init_ui()
        self._refresh_ports()

    def _apply_dark_style(self):
        self.setStyleSheet("""
            QMainWindow, QWidget {
                background-color: #1e1e2e;
                color: #cdd6f4;
                font-family: 'Segoe UI', Arial, sans-serif;
                font-size: 13px;
            }
            QGroupBox {
                font-weight: bold;
                border: 1px solid #45475a;
                border-radius: 8px;
                margin-top: 12px;
                padding-top: 10px;
                color: #89b4fa;
            }
            QGroupBox::title {
                subcontrol-origin: margin;
                subcontrol-position: top left;
                padding: 0 5px;
            }
            QComboBox, QLineEdit {
                background-color: #313244;
                border: 1px solid #45475a;
                border-radius: 5px;
                padding: 6px;
                color: #cdd6f4;
            }
            QPushButton {
                background-color: #313244;
                border: 1px solid #45475a;
                border-radius: 5px;
                padding: 7px 14px;
                font-weight: bold;
                color: #cdd6f4;
            }
            QPushButton:hover {
                background-color: #45475a;
                border-color: #89b4fa;
            }
            QPushButton:pressed {
                background-color: #585b70;
            }
            QPushButton#btnConnect {
                background-color: #a6e3a1;
                color: #11111b;
            }
            QPushButton#btnConnect:hover {
                background-color: #94e28f;
            }
            QPushButton#btnDisconnect {
                background-color: #f38ba8;
                color: #11111b;
            }
            QPushButton#btnPair {
                background-color: #f9e2af;
                color: #11111b;
                font-size: 14px;
                padding: 10px;
            }
            QPushButton#btnPair:hover {
                background-color: #f8d896;
            }
            QTextEdit {
                background-color: #11111b;
                border: 1px solid #313244;
                border-radius: 6px;
                font-family: 'Consolas', 'Courier New', monospace;
                font-size: 13px;
                padding: 8px;
                color: #a6e3a1;
            }
        """)

    def _init_ui(self):
        main_widget = QWidget()
        self.setCentralWidget(main_widget)
        layout = QVBoxLayout(main_widget)

        # ── Panel de Conexión ────────────────────────────────────────────────
        group_conn = QGroupBox("🔌 Conexión USB / Puerto Serial")
        layout_conn = QHBoxLayout(group_conn)

        layout_conn.addWidget(QLabel("Puerto:"))
        self.combo_ports = QComboBox()
        self.combo_ports.setMinimumWidth(250)
        layout_conn.addWidget(self.combo_ports)

        self.btn_refresh = QPushButton("🔄")
        self.btn_refresh.setToolTip("Actualizar lista de puertos")
        self.btn_refresh.clicked.connect(self._refresh_ports)
        layout_conn.addWidget(self.btn_refresh)

        layout_conn.addWidget(QLabel("Baudios:"))
        self.combo_baud = QComboBox()
        self.combo_baud.addItems(["115200", "9600", "38400", "57600"])
        layout_conn.addWidget(self.combo_baud)

        self.btn_connect = QPushButton("Conectar")
        self.btn_connect.setObjectName("btnConnect")
        self.btn_connect.clicked.connect(self._toggle_connection)
        layout_conn.addWidget(self.btn_connect)

        layout.addWidget(group_conn)

        # ── Panel de Control y Comandos ──────────────────────────────────────
        group_ctrl = QGroupBox("🎮 Panel de Comandos Colmena")
        layout_ctrl = QVBoxLayout(group_ctrl)

        # Botón principal de emparejamiento
        self.btn_pair = QPushButton("⚡ DISPARAR EMPAREJAMIENTO (PAIR)")
        self.btn_pair.setObjectName("btnPair")
        self.btn_pair.setToolTip("Envía el comando 'PAIR' por serial para anunciar el nodo al Gateway sin usar botón físico")
        self.btn_pair.clicked.connect(lambda: self._send_command("PAIR"))
        self.btn_pair.setEnabled(False)
        layout_ctrl.addWidget(self.btn_pair)

        # Sub-botones rápidos
        layout_quick = QHBoxLayout()
        self.btn_status = QPushButton("ℹ️ Consultar Estado (STATUS)")
        self.btn_status.clicked.connect(lambda: self._send_command("STATUS"))
        self.btn_status.setEnabled(False)
        layout_quick.addWidget(self.btn_status)

        self.btn_on = QPushButton("💡 Encender Relay (ON)")
        self.btn_on.clicked.connect(lambda: self._send_command("ON"))
        self.btn_on.setEnabled(False)
        layout_quick.addWidget(self.btn_on)

        self.btn_off = QPushButton("🌑 Apagar Relay (OFF)")
        self.btn_off.clicked.connect(lambda: self._send_command("OFF"))
        self.btn_off.setEnabled(False)
        layout_quick.addWidget(self.btn_off)

        layout_ctrl.addLayout(layout_quick)

        # Barra de comando personalizado
        layout_custom = QHBoxLayout()
        layout_custom.addWidget(QLabel("Comando Libre:"))
        self.input_cmd = QLineEdit()
        self.input_cmd.setPlaceholderText("Escribe cualquier comando serial (ej: PAIR, STATUS, HELP) y presiona Enter...")
        self.input_cmd.returnPressed.connect(self._send_custom_cmd)
        self.input_cmd.setEnabled(False)
        layout_custom.addWidget(self.input_cmd)

        self.btn_send = QPushButton("Enviar 📤")
        self.btn_send.clicked.connect(self._send_custom_cmd)
        self.btn_send.setEnabled(False)
        layout_custom.addWidget(self.btn_send)

        layout_ctrl.addLayout(layout_custom)
        layout.addWidget(group_ctrl)

        # ── Consola en Tiempo Real ───────────────────────────────────────────
        group_console = QGroupBox("📜 Consola en Vivo (Respuestas del Microcontrolador)")
        layout_console = QVBoxLayout(group_console)

        self.console_view = QTextEdit()
        self.console_view.setReadOnly(True)
        layout_console.addWidget(self.console_view)

        layout_console_btn = QHBoxLayout()
        self.btn_clear = QPushButton("🗑️ Limpiar Consola")
        self.btn_clear.clicked.connect(self.console_view.clear)
        layout_console_btn.addStretch()
        layout_console_btn.addWidget(self.btn_clear)
        layout_console.addLayout(layout_console_btn)

        layout.addWidget(group_console)

        self._log_system("Bienvenido a TestSerial Qt6. Selecciona el puerto COM de tu RP2040 y haz clic en Conectar.")

    def _log_system(self, text):
        ts = time.strftime("%H:%M:%S")
        self.console_view.append(f'<span style="color:#89b4fa;"><b>[{ts}] [SISTEMA]</b> {text}</span>')

    def _log_tx(self, text):
        ts = time.strftime("%H:%M:%S")
        self.console_view.append(f'<span style="color:#f9e2af;"><b>[{ts}] [TX ➔ NODO]</b> {text}</span>')

    def _log_rx(self, text):
        ts = time.strftime("%H:%M:%S")
        color = "#a6e3a1"
        if "ERROR" in text.upper() or "FAIL" in text.upper():
            color = "#f38ba8"
        elif "ANUNCIO" in text.upper() or "PAIR" in text.upper() or "✔️" in text:
            color = "#f5c2e7"
        self.console_view.append(f'<span style="color:{color};"><b>[{ts}] [RX ⬅ NODO]</b> {text}</span>')

    def _refresh_ports(self):
        if not serial:
            self._log_system("❌ pyserial no está instalado.")
            return

        self.combo_ports.clear()
        ports = serial.tools.list_ports.comports()
        if not ports:
            self.combo_ports.addItem("Ningún puerto detectado")
            return

        for p in ports:
            self.combo_ports.addItem(f"{p.device} — {p.description}", p.device)

    def _toggle_connection(self):
        if self.serial_conn and self.serial_conn.is_open:
            self._disconnect_serial()
        else:
            self._connect_serial()

    def _connect_serial(self):
        if not serial:
            QMessageBox.critical(self, "Error", "Falta la librería pyserial.")
            return

        port_data = self.combo_ports.currentData() or self.combo_ports.currentText().split(" ")[0]
        if not port_data or "Ningún" in port_data:
            QMessageBox.warning(self, "Aviso", "Por favor selecciona un puerto serial válido.")
            return

        baud = int(self.combo_baud.currentText())
        try:
            # En RP2040/ESP, NO alternar DTR/RTS manualmente después de abrir porque provoca un reinicio del chip
            self.serial_conn = serial.Serial(port_data, baud, timeout=0.1)
            
            self._log_system(f"✅ Conectado a {port_data} ({baud} bps). Escuchando en vivo...")

            # Iniciar hilo de lectura
            self.reader_thread = SerialReaderThread(self.serial_conn)
            self.reader_thread.data_received.connect(self._log_rx)
            self.reader_thread.error_occurred.connect(lambda err: self._log_system(f"⚠️ Error serial: {err}"))
            self.reader_thread.start()

            # Actualizar controles UI
            self.btn_connect.setText("Desconectar")
            self.btn_connect.setObjectName("btnDisconnect")
            self.btn_connect.style().unpolish(self.btn_connect)
            self.btn_connect.style().polish(self.btn_connect)
            self.combo_ports.setEnabled(False)
            self.combo_baud.setEnabled(False)

            self.btn_pair.setEnabled(True)
            self.btn_status.setEnabled(True)
            self.btn_on.setEnabled(True)
            self.btn_off.setEnabled(True)
            self.input_cmd.setEnabled(True)
            self.btn_send.setEnabled(True)

            # Consultar estado a los 1500ms luego de abrir el puerto para dar tiempo a estabilizar USB CDC
            QTimer.singleShot(1500, lambda: self._send_command("STATUS"))

        except Exception as e:
            self._log_system(f"❌ No se pudo abrir el puerto {port_data}: {e}")
            QMessageBox.critical(self, "Error de Conexión", f"No se pudo conectar a {port_data}:\n{e}")

    def _disconnect_serial(self):
        if self.reader_thread:
            self.reader_thread.stop()
            self.reader_thread = None

        if self.serial_conn and self.serial_conn.is_open:
            self.serial_conn.close()

        self.serial_conn = None
        self._log_system("🔌 Puerto serial desconectado.")

        self.btn_connect.setText("Conectar")
        self.btn_connect.setObjectName("btnConnect")
        self.btn_connect.style().unpolish(self.btn_connect)
        self.btn_connect.style().polish(self.btn_connect)
        self.combo_ports.setEnabled(True)
        self.combo_baud.setEnabled(True)

        self.btn_pair.setEnabled(False)
        self.btn_status.setEnabled(False)
        self.btn_on.setEnabled(False)
        self.btn_off.setEnabled(False)
        self.input_cmd.setEnabled(False)
        self.btn_send.setEnabled(False)

    def _send_command(self, cmd_text):
        if not self.serial_conn or not self.serial_conn.is_open:
            return
        try:
            self._log_tx(cmd_text)
            # Usar \r\n (CRLF) para garantizar compatibilidad con búferes seriales de Windows y USB CDC
            self.serial_conn.write(f"{cmd_text}\r\n".encode("utf-8"))
            self.serial_conn.flush()
        except Exception as e:
            self._log_system(f"❌ Error al enviar comando '{cmd_text}': {e}")

    def _send_custom_cmd(self):
        text = self.input_cmd.text().strip()
        if text:
            self._send_command(text)
            self.input_cmd.clear()

    def closeEvent(self, event):
        self._disconnect_serial()
        super().closeEvent(event)

    @classmethod
    def run(cls):
        """Método estático para lanzar la interfaz limpiamente desde main o pair_device.py"""
        app = QApplication.instance()
        if not app:
            app = QApplication(sys.argv)
        window = cls()
        window.show()
        sys.exit(app.exec())


if __name__ == "__main__":
    TestSerial.run()
