--1 up
CREATE TABLE IF NOT EXISTS tenant (
    id                  SERIAL NOT NULL PRIMARY KEY,
    ident               VARCHAR(16) NOT NULL UNIQUE,
    name                VARCHAR(64) NOT NULL
);
CREATE TABLE IF NOT EXISTS tenant_map (
    id                  SERIAL NOT NULL PRIMARY KEY,
    tenant              INTEGER NOT NULL REFERENCES tenant (id) DEFERRABLE INITIALLY DEFERRED,
    hostname            VARCHAR(255) NOT NULL UNIQUE
);
CREATE TABLE IF NOT EXISTS account (
    id                  SERIAL NOT NULL PRIMARY KEY,
    tenant              INTEGER NOT NULL REFERENCES tenant (id) DEFERRABLE INITIALLY DEFERRED,
    email               VARCHAR(255) NOT NULL,
    name                VARCHAR(255) NOT NULL
);
CREATE TABLE IF NOT EXISTS account_json (
    id                  SERIAL NOT NULL PRIMARY KEY,
    account             INTEGER NOT NULL REFERENCES account (id) DEFERRABLE INITIALLY DEFERRED,
    json_data           TEXT NOT NULL DEFAULT '{}'
);
CREATE TABLE IF NOT EXISTS auth_nonce (
    id                  SERIAL NOT NULL PRIMARY KEY,
    nonce               VARCHAR(48) NOT NULL UNIQUE
);

--1 down
DROP TABLE account_json;
DROP TABLE account;
DROP TABLE tenant_map;
DROP TABLE tenant;
DROP TABLE auth_nonce;

--2 up
ALTER TABLE auth_nonce ADD used INTEGER NOT NULL DEFAULT 0;

--3 up
INSERT INTO tenant (ident, name) VALUES ('benlocal', 'Ben Local Test');
INSERT INTO tenant_map (tenant, hostname) VALUES (1, 'localhost');

--3 down

--4 up
ALTER TABLE auth_nonce ADD created TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP;

--4 down

--5 up
ALTER TABLE account ADD expires_at INTEGER NOT NULL DEFAULT 0;
ALTER TABLE account ADD access_token VARCHAR(255) NOT NULL DEFAULT '*';

--5 down

--6 up
ALTER TABLE account DROP COLUMN expires_at;
ALTER TABLE account DROP COLUMN access_token;

CREATE TABLE backend_token (
    token           VARCHAR(64) NOT NULL PRIMARY KEY,
    account         INTEGER NOT NULL REFERENCES account (id) DEFERRABLE INITIALLY DEFERRED,
    expires_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP + INTERVAL '1 year'
);

INSERT INTO tenant (ident, name) VALUES ('kcdevkit', 'Dev Kit Environment');
INSERT INTO tenant_map (tenant, hostname) VALUES (2, 'kc-backend.dev.kit.cm');

--6 down
DROP TABLE backend_token CASCADE;

--7 up
CREATE TABLE role_definition (
    id              SERIAL NOT NULL PRIMARY KEY,
    ident           VARCHAR(32) NOT NULL,
    label           VARCHAR(255) NOT NULL
);
INSERT INTO role_definition (id, ident, label) VALUES (0, 'user', 'Regular user rights');
INSERT INTO role_definition (ident, label) VALUES ('admin.global', 'Global administrator rights');
INSERT INTO role_definition (ident, label) VALUES ('admin.tenant', 'Tenant administrator rights');
ALTER TABLE account DROP COLUMN tenant;

INSERT INTO tenant (id, ident, name) VALUES (0, '#system', '#system');
ALTER TABLE backend_token ADD COLUMN tenant INTEGER NOT NULL DEFAULT 0 REFERENCES tenant (id) DEFERRABLE INITIALLY DEFERRED;

--8 up
ALTER TABLE account_json ADD COLUMN tenant INTEGER NOT NULL REFERENCES tenant (id) DEFERRABLE INITIALLY DEFERRED;
