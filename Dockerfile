# Imagen para desplegar Maykel Repuestos 2 (Render, Railway, Fly.io, etc.).
# Compila la app Flutter web y el servidor Dart, y deja todo en un solo
# contenedor: el backend sirve la API y la app en el mismo puerto.

# ---- 1. App Flutter web ----
FROM ghcr.io/cirruslabs/flutter:stable AS web
WORKDIR /src/app
COPY app/pubspec.yaml app/pubspec.lock ./
RUN flutter pub get
COPY app/ ./
RUN flutter build web --release

# ---- 2. Servidor Dart (compilado a ejecutable nativo) ----
FROM dart:stable AS server
WORKDIR /src/backend
COPY backend/pubspec.yaml backend/pubspec.lock ./
RUN dart pub get
COPY backend/ ./
RUN dart compile exe bin/server.dart -o bin/server

# ---- 3. Imagen final ----
# Se usa la misma imagen de Dart para que el ejecutable tenga exactamente
# las bibliotecas del sistema con que se compiló.
FROM dart:stable
WORKDIR /srv
COPY --from=server /src/backend/bin/server /srv/backend/bin/server
COPY --from=web /src/app/build/web /srv/app/build/web

ENV WEB_DIR=/srv/app/build/web
# Render (y otras plataformas) definen PORT al arrancar; 8080 es solo el
# valor por defecto para pruebas con `docker run`.
ENV PORT=8080
EXPOSE 8080

CMD ["/srv/backend/bin/server"]
