-- Crear base de datos adicional para maestro si está configurada
SET @maestro_db = IFNULL(NULLIF(GETENV('MYSQL_DATABASE_MAESTRO'), ''), 'maestro_db');
SET @maestro_user = IFNULL(NULLIF(GETENV('MYSQL_USER_MAESTRO'), ''), 'maestro_user');
SET @maestro_pass = IFNULL(NULLIF(GETENV('MYSQL_PASSWORD_MAESTRO'), ''), 'abc123');

-- Crear base de datos
SET @create_db = CONCAT('CREATE DATABASE IF NOT EXISTS `', @maestro_db, '` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci');
PREPARE stmt FROM @create_db;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Crear usuario
SET @create_user = CONCAT('CREATE USER IF NOT EXISTS ''', @maestro_user, '''@''%'' IDENTIFIED BY ''', @maestro_pass, '''');
PREPARE stmt FROM @create_user;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Otorgar privilegios
SET @grant_priv = CONCAT('GRANT ALL PRIVILEGES ON `', @maestro_db, '`.* TO ''', @maestro_user, '''@''%''');
PREPARE stmt FROM @grant_priv;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

FLUSH PRIVILEGES;
