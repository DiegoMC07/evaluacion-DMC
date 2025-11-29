Sistema de Gestión de Entregas Móviles (Flutter)
Este proyecto es una aplicación móvil (compatible con web) desarrollada en Flutter para agentes de reparto. Permite a los agentes visualizar los paquetes que tienen asignados y registrar la finalización de la entrega con evidencia fotográfica y geolocalización GPS, comunicándose con un sistema backend a través de una API REST.
Requisitos Previos
Antes de comenzar, asegúrate de tener instalado y configurado lo siguiente:
Flutter SDK: Versión 3.x o superior.
Dart SDK: Incluido con Flutter.
Git: Para clonar el repositorio.
Backend/API REST: Un servidor funcionando que exponga los endpoints de /login, /paquetes/{agenteId} y /entregar (subida multipart).
Nota Importante: El backend debe estar configurado para manejar la subida de archivos (MultipartRequest) y la autenticación con tokens JWT.
Instalación y Configuración
Sigue estos pasos para poner en marcha el proyecto:
1. Clonar el Repositorio
Abre tu terminal y ejecuta:
git clone <URL_DEL_REPOSITORIO>
cd nombre-del-proyecto

2. Instalar Dependencias
Desde la raíz del proyecto, instala todas las dependencias de Flutter:
flutter pub get

3. Configurar la URL Base de la API (CRÍTICO)
Debes asegurarte de que la aplicación sepa dónde encontrar tu backend.
Abre el archivo lib/services/api_service.dart.
Modifica la constante baseUrl con la dirección correcta de tu servidor.
// lib/services/api_service.dart

class ApiService {
  // ATENCIÓN: Ajustar esta URL según tu entorno:
  // - '[http://10.0.2.2:8000](http://10.0.2.2:8000)' para Emulador Android
  // - '[http://127.0.0.1:8000](http://127.0.0.1:8000)' para iOS Simulator o Flutter Web/Desktop
  static const String baseUrl = '[http://127.0.0.1:8000](http://127.0.0.1:8000)'; 
  // ...
}

4. Configuración de Permisos
Asegúrate de que los permisos de Cámara y Localización estén configurados en los archivos nativos (Android/iOS) para que las librerías image_picker y geolocator funcionen correctamente.
Ejecución de la Aplicación
Puedes ejecutar la aplicación en el navegador, en un emulador o en un dispositivo físico.
En Emulador/Dispositivo (Android/iOS)
flutter run

En Navegador (Web)
flutter run -d chrome 
# o el navegador que prefieras

Uso
El flujo operativo básico para el agente de reparto es el siguiente:
Inicio de Sesión: El agente introduce sus credenciales. Si la autenticación es exitosa, se recibe y almacena de forma segura un token JWT y el ID del agente.
Lista de Entregas: La aplicación navega a DeliveriesListScreen, que llama al endpoint /paquetes/{agenteId} para mostrar la lista de paquetes asignados al agente autenticado.
Detalle de Paquete: Al seleccionar un paquete, el agente ve la dirección, el nombre del receptor y el estado actual.
Completar Entrega:
El agente debe hacer clic en "Tomar Foto" para capturar la evidencia.
Una vez tomada la foto, el botón "MARCAR COMO ENTREGADO" se activa.
Al hacer clic, la aplicación:
Obtiene la ubicación GPS actual del dispositivo (geolocator).
Obtiene los bytes de la foto (XFile.readAsBytes()).
Envía la petición POST con la foto, la ubicación y los IDs a la API (api_service.subirEntrega).
Si la API responde con éxito, el estado del paquete se actualiza a ENTREGADO, y la lista de paquetes se refresca.
