# 🏍️ MotoMap — Sistema Geoespacial para Motociclistas

> **MotoMap** es una aplicación móvil nativa para Android desarrollada bajo el patrón **MVVM** que centraliza en un único mapa interactivo la ubicación de estaciones de gasolina, puntos de carga eléctrica y talleres mecánicos. Permite filtrar los servicios en tiempo real según el presupuesto del usuario o la marca del vehículo, integrando almacenamiento local con **Room** y caché offline para garantizar su funcionamiento sin conexión.

## 🛠️ Tecnologías Utilizadas

## 📂 Estructura del Proyecto

```
MotoMap/
├── app/         # App Android (Java, MVVM, Room, Retrofit, Google Maps SDK)
├── backend/     # API REST (Node.js + Express + pg)
├── database/    # schema_postgis.sql (tablas + datos geoespaciales de ejemplo)
└── docker-compose.yml # Base de datos lista con un solo comando

```

## 🚀 Arranque Rápido *(Orden Importante)*

### 1️⃣ Base de Datos

* **Opción A — Con Docker (Recomendada):**

  ```
  docker compose up -d
  
  ```

* **Opción B — PostgreSQL Instalado Manualmente:**

  1. Crear la base de datos `motomap`.

  2. Habilitar la extensión **PostGIS**:

     ```
     CREATE EXTENSION postgis;
     
     ```

  3. Ejecutar el script `database/schema_postgis.sql`.

### 2️⃣ Backend (API REST)

```
cd backend
npm install
npm start

```

* **Verificación:** Abre en tu navegador `http://localhost:8080/health` (debe retornar `{"estado":"ok"}`).

* *Nota:* Si utilizas una contraseña distinta a `motomap1234`, edita el archivo `backend/.env`.

### 3️⃣ Aplicación Android

1. Abre **Android Studio** $\rightarrow$ `File` $\rightarrow$ `Open` $\rightarrow$ Selecciona la carpeta **MotoMap** (la que contiene el archivo `settings.gradle`).

2. En tu archivo `local.properties`, agrega la clave de Google Maps SDK:

   ```
   MAPS_API_KEY=tu_clave_de_google_maps
   
   ```

3. Sincroniza Gradle (`Sync Gradle`), crea un emulador con Google Play (API 34 o superior) y ejecuta la aplicación (`Run`).

4. **Configuración de Ubicación en Emulador:**

   * Haz clic en los tres puntos (`...`) $\rightarrow$ `Location` $\rightarrow$ Establece las coordenadas de Bucaramanga (`7.1193, -73.1227`).

> 💡 **Nota de Conexión HTTP:**
>
> * **Emulador:** Se conecta al backend de tu equipo mediante `http://10.0.2.2:8080/`.
>
> * **Dispositivo Físico:** Configura en `app/build.gradle` (`BASE_URL`) la dirección IP local de tu PC en la red Wi-Fi (ejemplo: `http://192.168.1.50:8080/`).