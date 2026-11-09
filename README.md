MotoMap — App Android (Java) + Backend (Node.js) + PostgreSQL/PostGIS
MotoMap/
├── app/            App Android (Java, MVVM, Room, Retrofit, Google Maps)
├── backend/        API REST (Node.js + Express + pg)
├── database/       schema_postgis.sql (tablas + datos de ejemplo)
└── docker-compose.yml   Base de datos lista con un solo comando
Arranque rápido (orden importante)
1) Base de datos
Opción A — con Docker (recomendada): docker compose up -d
Opción B — PostgreSQL instalado a mano (ver instrucciones en el chat): crear la base "motomap", habilitar PostGIS y ejecutar database/schema_postgis.sql
2) Backend
cd backend
npm install
npm start
Verifica en el navegador:  http://localhost:8080/health   (debe mostrar "estado":"ok") Si usaste una contraseña distinta a motomap1234, edita backend/.env
3) App Android
1.
Android Studio > File > Open > carpeta MotoMap (la que tiene settings.gradle).
2.
En local.properties agrega:  MAPS_API_KEY=tu_clave_de_google_maps
3.
Sync Gradle, crea un emulador con Google Play (API 34) y pulsa Run.
4.
En el emulador: ... > Location > fija Bucaramanga (7.1193, -73.1227).
El emulador accede al backend de tu PC por http://10.0.2.2:8080/ Con un celular físico: pon en app/build.gradle (BASE_URL) la IP de tu PC en la red WiFi, ej. http://192.168.1.50:8080/
