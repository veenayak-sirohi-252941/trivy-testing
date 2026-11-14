-- Run once by the official PostgreSQL image when its data directory is empty.
-- The database itself is created from POSTGRES_DB in docker-compose.yml.

CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(128) NOT NULL
);

CREATE TABLE IF NOT EXISTS team_members (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    pokemon_id INTEGER NOT NULL,
    name VARCHAR(100) NOT NULL,
    sprite VARCHAR(255) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_team_members_user_id
    ON team_members(user_id);
