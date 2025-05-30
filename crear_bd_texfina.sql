-- SCRIPT SQL SERVER - MODELO DE INSUMOS TEXFINA
-- Fecha de generación: 2025-05-29 15:03:56
-- Adaptado para SQL Server con INT IDENTITY

-- Crear la base de datos
CREATE DATABASE TexfinaDB;
GO

USE TexfinaDB;
GO

-- Tabla CLASE
CREATE TABLE CLASE (
    id_clase NVARCHAR(50) PRIMARY KEY,
    familia NVARCHAR(100),
    sub_familia NVARCHAR(100)
);

-- Tabla UNIDAD
CREATE TABLE UNIDAD (
    id_unidad NVARCHAR(50) PRIMARY KEY,
    nombre NVARCHAR(100)
);

-- Tabla ROL
CREATE TABLE ROL (
    id_rol NVARCHAR(50) PRIMARY KEY,
    nombre NVARCHAR(100),
    descripcion NVARCHAR(200)
);

-- Tabla TIPO_USUARIO
CREATE TABLE TIPO_USUARIO (
    id_tipo_usuario INT IDENTITY(1,1) PRIMARY KEY,
    descripcion NVARCHAR(100),
    requiere_cierre_automatico BIT
);

-- Tabla USUARIO
CREATE TABLE USUARIO (
    id_usuario INT IDENTITY(1,1) PRIMARY KEY,
    username NVARCHAR(50) UNIQUE NOT NULL,
    email NVARCHAR(100),
    password_hash NVARCHAR(255),
    id_rol NVARCHAR(50) REFERENCES ROL(id_rol),
    id_tipo_usuario INT REFERENCES TIPO_USUARIO(id_tipo_usuario),
    activo BIT DEFAULT 1,
    created_at DATETIME2 DEFAULT GETDATE(),
    last_login DATETIME2
);

-- Tabla PERMISO
CREATE TABLE PERMISO (
    id_permiso INT IDENTITY(1,1) PRIMARY KEY,
    nombre NVARCHAR(100),
    descripcion NVARCHAR(200)
);

-- Tabla ROL_PERMISO
CREATE TABLE ROL_PERMISO (
    id INT IDENTITY(1,1) PRIMARY KEY,
    id_rol NVARCHAR(50) REFERENCES ROL(id_rol),
    id_permiso INT REFERENCES PERMISO(id_permiso)
);

-- Tabla SESION (mantiene UNIQUEIDENTIFIER para seguridad)
CREATE TABLE SESION (
    id_sesion UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    id_usuario INT REFERENCES USUARIO(id_usuario),
    inicio DATETIME2,
    fin DATETIME2,
    cerrada_automaticamente BIT
);

-- Tabla LOG_EVENTO
CREATE TABLE LOG_EVENTO (
    id INT IDENTITY(1,1) PRIMARY KEY,
    id_usuario INT REFERENCES USUARIO(id_usuario),
    accion NVARCHAR(100),
    descripcion NVARCHAR(500),
    ip_origen NVARCHAR(50),
    modulo NVARCHAR(100),
    tabla_afectada NVARCHAR(100),
    timestamp DATETIME2 DEFAULT GETDATE()
);

-- Tabla PROVEEDOR
CREATE TABLE PROVEEDOR (
    id_proveedor INT IDENTITY(1,1) PRIMARY KEY,
    empresa NVARCHAR(200),
    ruc NVARCHAR(20),
    contacto NVARCHAR(200),
    direccion NVARCHAR(500),
    created_at DATETIME2 DEFAULT GETDATE(),
    updated_at DATETIME2 DEFAULT GETDATE()
);

-- Tabla INSUMO
CREATE TABLE INSUMO (
    id_insumo INT IDENTITY(1,1) PRIMARY KEY,
    id_fox NVARCHAR(50),
    nombre NVARCHAR(200),
    id_clase NVARCHAR(50) REFERENCES CLASE(id_clase),
    peso_unitario FLOAT,
    id_unidad NVARCHAR(50) REFERENCES UNIDAD(id_unidad),
    presentacion NVARCHAR(100),
    precio_unitario FLOAT,
    created_at DATETIME2 DEFAULT GETDATE(),
    updated_at DATETIME2 DEFAULT GETDATE()
);

-- Tabla INSUMO_PROVEEDOR
CREATE TABLE INSUMO_PROVEEDOR (
    id INT IDENTITY(1,1) PRIMARY KEY,
    id_insumo INT REFERENCES INSUMO(id_insumo),
    id_proveedor INT REFERENCES PROVEEDOR(id_proveedor),
    precio_unitario FLOAT
);

-- Tabla LOTE
CREATE TABLE LOTE (
    id_lote INT IDENTITY(1,1) PRIMARY KEY,
    id_insumo INT REFERENCES INSUMO(id_insumo),
    lote NVARCHAR(100),
    ubicacion NVARCHAR(200),
    stock_inicial FLOAT,
    stock_actual FLOAT,
    fecha_expiracion DATE,
    precio_total FLOAT,
    estado_lote NVARCHAR(50)
);

-- Tabla ALMACEN
CREATE TABLE ALMACEN (
    id_almacen INT IDENTITY(1,1) PRIMARY KEY,
    nombre NVARCHAR(100),
    ubicacion NVARCHAR(200)
);

-- Tabla STOCK
CREATE TABLE STOCK (
    id_stock INT IDENTITY(1,1) PRIMARY KEY,
    id_insumo INT REFERENCES INSUMO(id_insumo),
    presentacion NVARCHAR(100),
    id_unidad NVARCHAR(50) REFERENCES UNIDAD(id_unidad),
    cantidad FLOAT,
    id_lote INT REFERENCES LOTE(id_lote),
    id_almacen INT REFERENCES ALMACEN(id_almacen),
    fecha_entrada DATETIME2,
    fecha_salida DATETIME2
);

-- Tabla INGRESO
CREATE TABLE INGRESO (
    id_ingreso INT IDENTITY(1,1) PRIMARY KEY,
    id_insumo INT REFERENCES INSUMO(id_insumo),
    id_insumo_proveedor INT REFERENCES INSUMO_PROVEEDOR(id),
    fecha DATE,
    presentacion NVARCHAR(100),
    id_unidad NVARCHAR(50) REFERENCES UNIDAD(id_unidad),
    cantidad FLOAT,
    id_lote INT REFERENCES LOTE(id_lote),
    precio_total_formula FLOAT,
    precio_unitario_historico FLOAT,
    numero_remision NVARCHAR(50),
    orden_compra NVARCHAR(50),
    estado NVARCHAR(50)
);

-- Tabla CONSUMO
CREATE TABLE CONSUMO (
    id_consumo INT IDENTITY(1,1) PRIMARY KEY,
    id_insumo INT REFERENCES INSUMO(id_insumo),
    area NVARCHAR(100),
    fecha DATE,
    cantidad FLOAT,
    id_lote INT REFERENCES LOTE(id_lote),
    estado NVARCHAR(50)
);

-- Tabla RECETA
CREATE TABLE RECETA (
    id_receta INT IDENTITY(1,1) PRIMARY KEY,
    nombre NVARCHAR(200)
);

-- Tabla RECETA_DETALLE
CREATE TABLE RECETA_DETALLE (
    id INT IDENTITY(1,1) PRIMARY KEY,
    id_receta INT REFERENCES RECETA(id_receta),
    id_insumo INT REFERENCES INSUMO(id_insumo),
    proporcion FLOAT,
    orden INT,
    tipo_medida NVARCHAR(50)
);

-- DATOS INICIALES

-- Insertar roles básicos
INSERT INTO ROL (id_rol, nombre, descripcion) VALUES 
('ADMIN', 'Administrador', 'Acceso completo al sistema'),
('SUPERVISOR', 'Supervisor', 'Supervisión de operaciones'),
('OPERARIO', 'Operario', 'Operaciones básicas de insumos'),
('CONSULTOR', 'Consultor', 'Solo consulta de información');

-- Insertar tipos de usuario
INSERT INTO TIPO_USUARIO (descripcion, requiere_cierre_automatico) VALUES 
('Usuario Regular', 0),
('Usuario Temporal', 1),
('Usuario Externo', 1);

-- Insertar permisos básicos
INSERT INTO PERMISO (nombre, descripcion) VALUES 
('USUARIOS_CREAR', 'Crear usuarios'),
('USUARIOS_EDITAR', 'Editar usuarios'),
('USUARIOS_ELIMINAR', 'Eliminar usuarios'),
('USUARIOS_CONSULTAR', 'Consultar usuarios'),
('INSUMOS_CREAR', 'Crear insumos'),
('INSUMOS_EDITAR', 'Editar insumos'),
('INSUMOS_ELIMINAR', 'Eliminar insumos'),
('INSUMOS_CONSULTAR', 'Consultar insumos'),
('STOCK_CONSULTAR', 'Consultar stock'),
('STOCK_GESTIONAR', 'Gestionar stock'),
('REPORTES_GENERAR', 'Generar reportes'),
('CONFIGURACION', 'Configuración del sistema'),
('PROVEEDORES_CREAR', 'Crear proveedores'),
('PROVEEDORES_EDITAR', 'Editar proveedores'),
('PROVEEDORES_ELIMINAR', 'Eliminar proveedores'),
('PROVEEDORES_CONSULTAR', 'Consultar proveedores'),
('LOTES_CREAR', 'Crear lotes'),
('LOTES_EDITAR', 'Editar lotes'),
('LOTES_ELIMINAR', 'Eliminar lotes'),
('LOTES_CONSULTAR', 'Consultar lotes'),
('INGRESOS_CREAR', 'Registrar ingresos'),
('INGRESOS_EDITAR', 'Editar ingresos'),
('INGRESOS_CONSULTAR', 'Consultar ingresos'),
('CONSUMOS_CREAR', 'Registrar consumos'),
('CONSUMOS_EDITAR', 'Editar consumos'),
('CONSUMOS_CONSULTAR', 'Consultar consumos'),
('RECETAS_CREAR', 'Crear recetas'),
('RECETAS_EDITAR', 'Editar recetas'),
('RECETAS_ELIMINAR', 'Eliminar recetas'),
('RECETAS_CONSULTAR', 'Consultar recetas'),
('ALMACENES_CREAR', 'Crear almacenes'),
('ALMACENES_EDITAR', 'Editar almacenes'),
('ALMACENES_ELIMINAR', 'Eliminar almacenes'),
('ALMACENES_CONSULTAR', 'Consultar almacenes');

-- Asignar todos los permisos al rol ADMIN
INSERT INTO ROL_PERMISO (id_rol, id_permiso)
SELECT 'ADMIN', id_permiso FROM PERMISO;

-- Asignar permisos limitados al rol SUPERVISOR
INSERT INTO ROL_PERMISO (id_rol, id_permiso)
SELECT 'SUPERVISOR', id_permiso 
FROM PERMISO 
WHERE nombre NOT IN ('USUARIOS_CREAR', 'USUARIOS_ELIMINAR', 'CONFIGURACION');

-- Asignar permisos básicos al rol OPERARIO
INSERT INTO ROL_PERMISO (id_rol, id_permiso)
SELECT 'OPERARIO', id_permiso 
FROM PERMISO 
WHERE nombre IN (
    'INSUMOS_CONSULTAR', 'STOCK_CONSULTAR', 'STOCK_GESTIONAR',
    'PROVEEDORES_CONSULTAR', 'LOTES_CONSULTAR', 'LOTES_CREAR', 'LOTES_EDITAR',
    'INGRESOS_CREAR', 'INGRESOS_CONSULTAR', 'CONSUMOS_CREAR', 'CONSUMOS_CONSULTAR',
    'ALMACENES_CONSULTAR'
);

-- Asignar solo permisos de consulta al rol CONSULTOR
INSERT INTO ROL_PERMISO (id_rol, id_permiso)
SELECT 'CONSULTOR', id_permiso 
FROM PERMISO 
WHERE nombre LIKE '%_CONSULTAR';

-- Insertar unidades básicas
INSERT INTO UNIDAD (id_unidad, nombre) VALUES 
('KG', 'Kilogramo'),
('LT', 'Litro'),
('UN', 'Unidad'),
('MT', 'Metro'),
('GR', 'Gramo'),
('ML', 'Mililitro'),
('CM', 'Centímetro'),
('M2', 'Metro Cuadrado'),
('M3', 'Metro Cúbico'),
('TON', 'Tonelada');

-- Insertar clases básicas
INSERT INTO CLASE (id_clase, familia, sub_familia) VALUES 
('QUIM', 'Químicos', 'Químicos Básicos'),
('QUIM_ACE', 'Químicos', 'Aceites y Lubricantes'),
('QUIM_SOL', 'Químicos', 'Solventes'),
('MAT_PRIMA', 'Materia Prima', 'Materia Prima Textil'),
('MAT_FIB', 'Materia Prima', 'Fibras'),
('MAT_HIL', 'Materia Prima', 'Hilos'),
('TINTAS', 'Tintas', 'Tintas de Impresión'),
('TINTAS_PIG', 'Tintas', 'Pigmentos'),
('ACAB', 'Acabados', 'Acabados Textiles'),
('ACAB_SOFT', 'Acabados', 'Suavizantes'),
('ACAB_RIG', 'Acabados', 'Rigidizantes'),
('MANT', 'Mantenimiento', 'Repuestos'),
('MANT_HER', 'Mantenimiento', 'Herramientas'),
('ENVASE', 'Envases', 'Contenedores'),
('ENVASE_BOL', 'Envases', 'Bolsas');

-- Insertar almacenes básicos
INSERT INTO ALMACEN (nombre, ubicacion) VALUES 
('Almacén Principal', 'Planta - Área A'),
('Almacén de Químicos', 'Planta - Área B'),
('Almacén de Tintas', 'Planta - Área C'),
('Almacén de Materia Prima', 'Planta - Área D'),
('Almacén de Acabados', 'Planta - Área E');

GO 