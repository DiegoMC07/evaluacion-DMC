
CREATE DATABASE IF NOT EXISTS paquexpress;
USE paquexpress;

DROP TABLE IF EXISTS entregas;
DROP TABLE IF EXISTS paquetes;
DROP TABLE IF EXISTS usuarios;


CREATE TABLE usuarios (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(120) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL, 
    rol ENUM('agente','admin') DEFAULT 'agente'
);


CREATE TABLE paquetes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    referencia VARCHAR(100) UNIQUE NOT NULL,
    direccion VARCHAR(255) NOT NULL,
    lat_destino FLOAT,
    lon_destino FLOAT,
    agente_asignado INT,
    estado ENUM('pendiente','en_ruta','entregado') DEFAULT 'pendiente',
    FOREIGN KEY (agente_asignado) REFERENCES usuarios(id)
);


CREATE TABLE entregas (
    id INT AUTO_INCREMENT PRIMARY KEY,
    paquete_id INT,
    agente_id INT,
    foto_url VARCHAR(255),
    lat_gps FLOAT,
    lon_gps FLOAT,
    FOREIGN KEY (paquete_id) REFERENCES paquetes(id),
    FOREIGN KEY (agente_id) REFERENCES usuarios(id)
);

INSERT INTO usuarios (nombre, email, password, rol) VALUES
('Agente Diego Prueba', 'agente@paquexpress.com', '123456', 'agente'),
('Administrador', 'admin@paquexpress.com', 'adminpass', 'admin');

INSERT INTO paquetes (referencia, direccion, lat_destino, lon_destino, agente_asignado, estado) VALUES
('P001A', 'Calle Falsa 123, Ciudad de México', 19.4326, -99.1332, 1, 'pendiente'),
('P002B', 'Avenida Siempre Viva 742, CDMX', 19.4320, -99.1300, 1, 'pendiente'),
('P003C', 'Entrega de Prueba Finalizada', 20.6597, -103.3496, 1, 'entregado');
