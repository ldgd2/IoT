# bthapp

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.



configuracion flutter

# 1) Variables
$SDK="C:\Dev\Android\Sdk"
$CLT_ZIP="$env:TEMP\cmdline-tools.zip"
$CLT_URL="https://dl.google.com/android/repository/commandlinetools-win-9477386_latest.zip"

# 2) Crear carpetas base
New-Item -ItemType Directory "$SDK\cmdline-tools\latest" -Force | Out-Null
New-Item -ItemType Directory "$SDK\platform-tools" -Force | Out-Null

# 3) Bajar y extraer Command-line tools
Invoke-WebRequest $CLT_URL -OutFile $CLT_ZIP
Expand-Archive $CLT_ZIP "$SDK\cmdline-tools\latest" -Force

# (algunos zips traen una subcarpeta 'cmdline-tools'; si quedó anidada, mueve su contenido)
if (Test-Path "$SDK\cmdline-tools\latest\cmdline-tools") {
  Copy-Item "$SDK\cmdline-tools\latest\cmdline-tools\*" "$SDK\cmdline-tools\latest" -Recurse -Force
  Remove-Item "$SDK\cmdline-tools\latest\cmdline-tools" -Recurse -Force
}

# 4) PATH temporal para esta sesión
$env:ANDROID_SDK_ROOT=$SDK
$env:ANDROID_HOME=$SDK
$env:PATH="$SDK\cmdline-tools\latest\bin;$SDK\platform-tools;$SDK\emulator;$env:PATH"

# 5) Instalar paquetes mínimos con sdkmanager
& "$SDK\cmdline-tools\latest\bin\sdkmanager.bat" --sdk_root="$SDK" --install "platform-tools" "build-tools;35.0.0" "platforms;android-34" "ndk;27.0.12077973"

# 6) Aceptar licencias
& "$SDK\cmdline-tools\latest\bin\sdkmanager.bat" --sdk_root="$SDK" --licenses
