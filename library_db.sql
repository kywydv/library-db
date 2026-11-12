-- =====================================================================
-- Лабораторна 1, варіант 6: Система управління бібліотекою (PostgreSQL)
-- Запуск: psql -U postgres -c "CREATE DATABASE library;" ; psql -U postgres -d library -f library_db.sql
-- =====================================================================

-- ---------- 1. ТАБЛИЦІ (19 сутностей) ----------
CREATE TABLE roles (
    id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE users (
    id            INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    role_id       INT NOT NULL REFERENCES roles(id),
    username      VARCHAR(50)  NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name     VARCHAR(150) NOT NULL,
    email         VARCHAR(150) NOT NULL UNIQUE,
    is_deleted    BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at    TIMESTAMP,
    created_at    TIMESTAMP NOT NULL DEFAULT now(),
    updated_at    TIMESTAMP,
    updated_by    INT REFERENCES users(id)
);

CREATE TABLE membership_types (
    id          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        VARCHAR(50) NOT NULL UNIQUE,
    max_books   INT NOT NULL CHECK (max_books > 0),
    loan_days   INT NOT NULL CHECK (loan_days > 0),
    monthly_fee NUMERIC(10,2) NOT NULL DEFAULT 0
);

CREATE TABLE members (
    id                 INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    membership_type_id INT NOT NULL REFERENCES membership_types(id),
    card_number        VARCHAR(20)  NOT NULL UNIQUE,
    full_name          VARCHAR(150) NOT NULL,
    phone              VARCHAR(20),
    email              VARCHAR(150),
    address            VARCHAR(255),
    registered_at      DATE NOT NULL DEFAULT current_date,
    expires_at         DATE,
    is_deleted         BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at         TIMESTAMP,
    updated_at         TIMESTAMP,
    updated_by         INT REFERENCES users(id)
);

CREATE TABLE authors (
    id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name  VARCHAR(150) NOT NULL,
    birth_year INT,
    country    VARCHAR(60)
);

CREATE TABLE publishers (
    id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(150) NOT NULL UNIQUE,
    city VARCHAR(80)
);

CREATE TABLE categories (
    id        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name      VARCHAR(100) NOT NULL UNIQUE,
    parent_id INT REFERENCES categories(id)
);

CREATE TABLE books (
    id           INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    publisher_id INT NOT NULL REFERENCES publishers(id),
    category_id  INT NOT NULL REFERENCES categories(id),
    title        VARCHAR(255) NOT NULL,
    isbn         VARCHAR(20) UNIQUE,
    publish_year INT,
    pages        INT,
    description  TEXT,
    is_deleted   BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at   TIMESTAMP,
    updated_at   TIMESTAMP,
    updated_by   INT REFERENCES users(id)
);

CREATE TABLE book_authors (
    book_id   INT NOT NULL REFERENCES books(id),
    author_id INT NOT NULL REFERENCES authors(id),
    PRIMARY KEY (book_id, author_id)
);

CREATE TABLE locations (
    id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    hall  VARCHAR(50) NOT NULL,
    shelf VARCHAR(20) NOT NULL
);

CREATE TABLE book_copies (
    id               INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    book_id          INT NOT NULL REFERENCES books(id),
    location_id      INT NOT NULL REFERENCES locations(id),
    inventory_number VARCHAR(30) NOT NULL UNIQUE,
    status           VARCHAR(20) NOT NULL DEFAULT 'available'
                     CHECK (status IN ('available','loaned','reserved','lost')),
    acquired_at      DATE,
    is_deleted       BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at       TIMESTAMP
);

CREATE TABLE loans (
    id          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    copy_id     INT NOT NULL REFERENCES book_copies(id),
    member_id   INT NOT NULL REFERENCES members(id),
    issued_by   INT NOT NULL REFERENCES users(id),
    loaned_at   TIMESTAMP NOT NULL DEFAULT now(),
    due_date    DATE NOT NULL,
    returned_at TIMESTAMP,
    updated_at  TIMESTAMP,
    updated_by  INT REFERENCES users(id)
);

CREATE TABLE reservations (
    id          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    book_id     INT NOT NULL REFERENCES books(id),
    member_id   INT NOT NULL REFERENCES members(id),
    reserved_at TIMESTAMP NOT NULL DEFAULT now(),
    expires_at  TIMESTAMP NOT NULL,
    status      VARCHAR(20) NOT NULL DEFAULT 'active'
);

CREATE TABLE fines (
    id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    loan_id    INT NOT NULL REFERENCES loans(id),
    amount     NUMERIC(10,2) NOT NULL,
    reason     VARCHAR(255),
    is_paid    BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP,
    updated_by INT REFERENCES users(id)
);

CREATE TABLE services (
    id          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        VARCHAR(100) NOT NULL UNIQUE,
    description VARCHAR(255),
    price       NUMERIC(10,2) NOT NULL,
    is_deleted  BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at  TIMESTAMP
);

CREATE TABLE service_orders (
    id           INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    service_id   INT NOT NULL REFERENCES services(id),
    member_id    INT NOT NULL REFERENCES members(id),
    processed_by INT NOT NULL REFERENCES users(id),
    quantity     INT NOT NULL DEFAULT 1,
    total_price  NUMERIC(10,2) NOT NULL,
    ordered_at   TIMESTAMP NOT NULL DEFAULT now(),
    status       VARCHAR(20) NOT NULL DEFAULT 'new',
    updated_at   TIMESTAMP,
    updated_by   INT REFERENCES users(id)
);

CREATE TABLE payments (
    id               INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    member_id        INT NOT NULL REFERENCES members(id),
    fine_id          INT REFERENCES fines(id),
    service_order_id INT REFERENCES service_orders(id),
    amount           NUMERIC(10,2) NOT NULL,
    method           VARCHAR(20) NOT NULL CHECK (method IN ('cash','card')),
    paid_at          TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE events (
    id           INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    organizer_id INT NOT NULL REFERENCES users(id),
    title        VARCHAR(150) NOT NULL,
    description  TEXT,
    starts_at    TIMESTAMP NOT NULL,
    capacity     INT NOT NULL
);

CREATE TABLE event_registrations (
    id            INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    event_id      INT NOT NULL REFERENCES events(id),
    member_id     INT NOT NULL REFERENCES members(id),
    registered_at TIMESTAMP NOT NULL DEFAULT now(),
    UNIQUE (event_id, member_id)
);

-- ---------- 2. ІНДЕКСИ (B-tree, partial, composite, GIN, Hash) ----------
CREATE INDEX ix_loans_member_due      ON loans (member_id, due_date);                         -- composite B-tree
CREATE INDEX ix_loans_active          ON loans (copy_id) WHERE returned_at IS NULL;           -- partial
CREATE INDEX ix_books_active_title    ON books (title) WHERE is_deleted = FALSE;              -- partial B-tree
CREATE INDEX ix_books_title_fts       ON books USING GIN (to_tsvector('simple', title));      -- GIN (повнотекстовий пошук)
CREATE INDEX ix_members_email_hash    ON members USING HASH (email);                          -- Hash
CREATE INDEX ix_copies_book_status    ON book_copies (book_id, status) WHERE is_deleted = FALSE;

-- ---------- 3. ТРИГЕРИ (3 функції-тригери, застосовані до кількох таблиць) ----------
-- T1: автоматичний updated_at
CREATE OR REPLACE FUNCTION trg_set_updated_at() RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER t_users_upd           BEFORE UPDATE ON users           FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();
CREATE TRIGGER t_members_upd         BEFORE UPDATE ON members         FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();
CREATE TRIGGER t_books_upd           BEFORE UPDATE ON books           FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();
CREATE TRIGGER t_loans_upd           BEFORE UPDATE ON loans           FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();
CREATE TRIGGER t_fines_upd           BEFORE UPDATE ON fines           FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();
CREATE TRIGGER t_service_orders_upd  BEFORE UPDATE ON service_orders  FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();

-- T2: штамп soft delete
CREATE OR REPLACE FUNCTION trg_soft_delete_stamp() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_deleted AND NOT OLD.is_deleted THEN
        NEW.deleted_at := now();
    ELSIF NOT NEW.is_deleted THEN
        NEW.deleted_at := NULL;
    END IF;
    RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER t_users_sd        BEFORE UPDATE ON users        FOR EACH ROW EXECUTE FUNCTION trg_soft_delete_stamp();
CREATE TRIGGER t_members_sd      BEFORE UPDATE ON members      FOR EACH ROW EXECUTE FUNCTION trg_soft_delete_stamp();
CREATE TRIGGER t_books_sd        BEFORE UPDATE ON books        FOR EACH ROW EXECUTE FUNCTION trg_soft_delete_stamp();
CREATE TRIGGER t_book_copies_sd  BEFORE UPDATE ON book_copies  FOR EACH ROW EXECUTE FUNCTION trg_soft_delete_stamp();
CREATE TRIGGER t_services_sd     BEFORE UPDATE ON services     FOR EACH ROW EXECUTE FUNCTION trg_soft_delete_stamp();

-- T3: синхронізація статусу примірника з видачею / поверненням
CREATE OR REPLACE FUNCTION trg_loan_copy_status() RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE book_copies SET status = 'loaned' WHERE id = NEW.copy_id;
    ELSIF TG_OP = 'UPDATE' AND OLD.returned_at IS NULL AND NEW.returned_at IS NOT NULL THEN
        UPDATE book_copies SET status = 'available' WHERE id = NEW.copy_id;
    END IF;
    RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER t_loans_copy_status AFTER INSERT OR UPDATE OF returned_at ON loans
    FOR EACH ROW EXECUTE FUNCTION trg_loan_copy_status();

-- ---------- 4. КОРИСТУВАЦЬКІ ФУНКЦІЇ (3) ----------
-- Штраф: 2.00 грн за кожен день прострочення
CREATE OR REPLACE FUNCTION fn_calc_fine(p_loan_id INT) RETURNS NUMERIC AS $$
DECLARE
    v_due  DATE;
    v_ret  TIMESTAMP;
    v_days INT;
BEGIN
    SELECT due_date, returned_at INTO v_due, v_ret FROM loans WHERE id = p_loan_id;
    IF NOT FOUND THEN RETURN 0; END IF;
    v_days := GREATEST(0, COALESCE(v_ret, now())::date - v_due);
    RETURN v_days * 2.00;
END; $$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION fn_available_copies(p_book_id INT) RETURNS INT AS $$
    SELECT COUNT(*)::int FROM book_copies
    WHERE book_id = p_book_id AND status = 'available' AND is_deleted = FALSE;
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION fn_member_active_loans(p_member_id INT) RETURNS INT AS $$
    SELECT COUNT(*)::int FROM loans WHERE member_id = p_member_id AND returned_at IS NULL;
$$ LANGUAGE sql STABLE;

-- ---------- 5. РОЗРІЗИ ДАНИХ / VIEW (4) ----------
CREATE OR REPLACE VIEW v_book_catalog AS
SELECT b.id,
       b.title,
       b.isbn,
       p.name AS publisher,
       c.name AS category,
       COALESCE(string_agg(a.full_name, ', ' ORDER BY a.full_name), '') AS authors,
       fn_available_copies(b.id) AS available_copies
FROM books b
JOIN publishers p ON p.id = b.publisher_id
JOIN categories c ON c.id = b.category_id
LEFT JOIN book_authors ba ON ba.book_id = b.id
LEFT JOIN authors a ON a.id = ba.author_id
WHERE b.is_deleted = FALSE
GROUP BY b.id, p.name, c.name;

CREATE OR REPLACE VIEW v_active_members AS
SELECT m.id,
       m.card_number,
       m.full_name,
       mt.name AS membership_type,
       mt.max_books,
       fn_member_active_loans(m.id) AS active_loans
FROM members m
JOIN membership_types mt ON mt.id = m.membership_type_id
WHERE m.is_deleted = FALSE;

CREATE OR REPLACE VIEW v_active_loans AS
SELECT l.id AS loan_id,
       l.copy_id,
       bc.inventory_number,
       b.title AS book_title,
       l.member_id,
       m.full_name AS member_name,
       l.loaned_at,
       l.due_date,
       GREATEST(0, current_date - l.due_date) AS days_overdue,
       fn_calc_fine(l.id) AS fine_amount
FROM loans l
JOIN book_copies bc ON bc.id = l.copy_id
JOIN books b ON b.id = bc.book_id
JOIN members m ON m.id = l.member_id
WHERE l.returned_at IS NULL;

CREATE OR REPLACE VIEW v_member_debts AS
SELECT m.id AS member_id,
       m.full_name,
       COALESCE(SUM(f.amount), 0) AS unpaid_total
FROM members m
LEFT JOIN loans l ON l.member_id = m.id
LEFT JOIN fines f ON f.loan_id = l.id AND f.is_paid = FALSE
WHERE m.is_deleted = FALSE
GROUP BY m.id, m.full_name;

-- ---------- 6. ЗБЕРЕЖЕНІ ПРОЦЕДУРИ (4) ----------
-- Видача книги. Повертає id видачі через INOUT.
CREATE OR REPLACE PROCEDURE sp_issue_book(
    p_copy_id INT, p_member_id INT, p_issued_by INT, INOUT p_loan_id INT DEFAULT NULL)
LANGUAGE plpgsql AS $$
DECLARE
    v_status    VARCHAR(20);
    v_max       INT;
    v_days      INT;
BEGIN
    SELECT status INTO v_status FROM book_copies
    WHERE id = p_copy_id AND is_deleted = FALSE FOR UPDATE;
    IF NOT FOUND OR v_status <> 'available' THEN
        RAISE EXCEPTION 'Примірник % недоступний для видачі', p_copy_id;
    END IF;

    SELECT mt.max_books, mt.loan_days INTO v_max, v_days
    FROM members m JOIN membership_types mt ON mt.id = m.membership_type_id
    WHERE m.id = p_member_id AND m.is_deleted = FALSE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Читача % не знайдено', p_member_id;
    END IF;

    IF fn_member_active_loans(p_member_id) >= v_max THEN
        RAISE EXCEPTION 'Читач % досяг ліміту книг (%)', p_member_id, v_max;
    END IF;

    INSERT INTO loans (copy_id, member_id, issued_by, due_date)
    VALUES (p_copy_id, p_member_id, p_issued_by, current_date + v_days)
    RETURNING id INTO p_loan_id;
END; $$;

-- Повернення книги + автоматичний штраф
CREATE OR REPLACE PROCEDURE sp_return_book(p_loan_id INT, p_updated_by INT)
LANGUAGE plpgsql AS $$
DECLARE
    v_fine NUMERIC;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM loans WHERE id = p_loan_id AND returned_at IS NULL) THEN
        RAISE EXCEPTION 'Активну видачу % не знайдено', p_loan_id;
    END IF;

    UPDATE loans SET returned_at = now(), updated_by = p_updated_by WHERE id = p_loan_id;

    v_fine := fn_calc_fine(p_loan_id);
    IF v_fine > 0 THEN
        INSERT INTO fines (loan_id, amount, reason, updated_by)
        VALUES (p_loan_id, v_fine, 'Прострочення повернення', p_updated_by);
    END IF;
END; $$;

-- Soft delete книги разом з її примірниками
CREATE OR REPLACE PROCEDURE sp_soft_delete_book(p_book_id INT, p_user_id INT)
LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM loans l JOIN book_copies bc ON bc.id = l.copy_id
               WHERE bc.book_id = p_book_id AND l.returned_at IS NULL) THEN
        RAISE EXCEPTION 'Книгу % не можна видалити: є активні видачі', p_book_id;
    END IF;

    UPDATE books SET is_deleted = TRUE, updated_by = p_user_id WHERE id = p_book_id AND is_deleted = FALSE;
    UPDATE book_copies SET is_deleted = TRUE WHERE book_id = p_book_id AND is_deleted = FALSE;
END; $$;

-- Реєстрація читача
CREATE OR REPLACE PROCEDURE sp_register_member(
    p_membership_type_id INT, p_card_number VARCHAR, p_full_name VARCHAR,
    p_phone VARCHAR, p_email VARCHAR, INOUT p_id INT DEFAULT NULL)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO members (membership_type_id, card_number, full_name, phone, email, expires_at)
    VALUES (p_membership_type_id, p_card_number, p_full_name, p_phone, p_email,
            current_date + INTERVAL '1 year')
    RETURNING id INTO p_id;
END; $$;

-- ---------- 7. ТЕСТОВІ ДАНІ ----------
INSERT INTO roles (name) VALUES ('admin'), ('librarian');
INSERT INTO users (role_id, username, password_hash, full_name, email)
VALUES (2, 'librarian1', 'hash', 'Олена Бібліотекар', 'lib@example.com');
INSERT INTO membership_types (name, max_books, loan_days, monthly_fee)
VALUES ('Стандарт', 3, 14, 0), ('Преміум', 10, 30, 100);
INSERT INTO publishers (name, city) VALUES ('А-БА-БА-ГА-ЛА-МА-ГА', 'Київ');
INSERT INTO categories (name) VALUES ('Художня література');
INSERT INTO authors (full_name, birth_year, country) VALUES ('Ліна Костенко', 1930, 'Україна');
INSERT INTO locations (hall, shelf) VALUES ('Зал 1', 'A-1');
INSERT INTO books (publisher_id, category_id, title, isbn, publish_year, pages)
VALUES (1, 1, 'Маруся Чурай', '978-0-00-000001-1', 2010, 160);
INSERT INTO book_authors (book_id, author_id) VALUES (1, 1);
INSERT INTO book_copies (book_id, location_id, inventory_number, acquired_at)
VALUES (1, 1, 'INV-0001', current_date), (1, 1, 'INV-0002', current_date);
INSERT INTO services (name, description, price)
VALUES ('Ксерокопія', 'Копіювання сторінки', 1.50), ('Друк', 'Друк документа', 2.00);
