-- আগের টেবিল থাকলে মুছে ফেলবে
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS delay_logs CASCADE;
DROP TABLE IF EXISTS tokens CASCADE;
DROP TABLE IF EXISTS appointments CASCADE;
DROP TABLE IF EXISTS doctor_schedules CASCADE;
DROP TABLE IF EXISTS doctors CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS departments CASCADE;

-- টেবিল ১: বিভাগ
CREATE TABLE departments (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    created_at  TIMESTAMP DEFAULT NOW()
);

-- টেবিল ২: সব ব্যবহারকারী
CREATE TABLE users (
    id            SERIAL PRIMARY KEY,
    full_name     VARCHAR(100) NOT NULL,
    email         VARCHAR(150) NOT NULL UNIQUE,
    phone         VARCHAR(20),
    password_hash VARCHAR(255) NOT NULL,
    role          VARCHAR(20) NOT NULL
                  CHECK (role IN ('patient', 'doctor', 'receptionist', 'admin')),
    fcm_token     TEXT,
    is_active     BOOLEAN DEFAULT TRUE,
    created_at    TIMESTAMP DEFAULT NOW()
);

-- টেবিল ৩: ডাক্তারের তথ্য
CREATE TABLE doctors (
    id                       SERIAL PRIMARY KEY,
    user_id                  INT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    department_id            INT NOT NULL REFERENCES departments(id),
    specialization           VARCHAR(100),
    room_no                  VARCHAR(20),
    avg_consultation_minutes INT DEFAULT 10,
    status                   VARCHAR(20) DEFAULT 'absent'
                             CHECK (status IN ('available', 'in_consultation', 'on_break', 'absent'))
);

-- টেবিল ৪: ডাক্তারের বসার সময়
CREATE TABLE doctor_schedules (
    id           SERIAL PRIMARY KEY,
    doctor_id    INT NOT NULL REFERENCES doctors(id) ON DELETE CASCADE,
    day_of_week  INT NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
    start_time   TIME NOT NULL,
    end_time     TIME NOT NULL,
    max_patients INT DEFAULT 30
);

-- টেবিল ৫: অ্যাপয়েন্টমেন্ট
CREATE TABLE appointments (
    id               SERIAL PRIMARY KEY,
    patient_id       INT NOT NULL REFERENCES users(id),
    doctor_id        INT NOT NULL REFERENCES doctors(id),
    appointment_date DATE NOT NULL,
    appointment_time TIME NOT NULL,
    reason           TEXT,
    status           VARCHAR(20) DEFAULT 'booked'
                     CHECK (status IN ('booked', 'checked_in', 'completed', 'cancelled', 'no_show')),
    created_at       TIMESTAMP DEFAULT NOW()
);

-- টেবিল ৬: টোকেন (কিউ)
CREATE TABLE tokens (
    id                     SERIAL PRIMARY KEY,
    appointment_id         INT UNIQUE REFERENCES appointments(id) ON DELETE SET NULL,
    patient_id             INT NOT NULL REFERENCES users(id),
    doctor_id              INT NOT NULL REFERENCES doctors(id),
    token_date             DATE NOT NULL DEFAULT CURRENT_DATE,
    token_number           INT NOT NULL,
    qr_code                VARCHAR(255) UNIQUE,
    priority               VARCHAR(20) DEFAULT 'normal'
                           CHECK (priority IN ('normal', 'emergency')),
    status                 VARCHAR(20) DEFAULT 'waiting'
                           CHECK (status IN ('waiting', 'called', 'in_consultation', 'completed', 'skipped', 'cancelled')),
    estimated_wait_minutes INT,
    check_in_time          TIMESTAMP DEFAULT NOW(),
    call_time              TIMESTAMP,
    finish_time            TIMESTAMP,
    UNIQUE (doctor_id, token_date, token_number)
);

-- টেবিল ৭: দেরির ইতিহাস
CREATE TABLE delay_logs (
    id            SERIAL PRIMARY KEY,
    doctor_id     INT NOT NULL REFERENCES doctors(id) ON DELETE CASCADE,
    delay_minutes INT NOT NULL,
    reason        VARCHAR(255),
    created_at    TIMESTAMP DEFAULT NOW()
);

-- টেবিল ৮: নোটিফিকেশন
CREATE TABLE notifications (
    id         SERIAL PRIMARY KEY,
    user_id    INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title      VARCHAR(150) NOT NULL,
    message    TEXT NOT NULL,
    is_read    BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- দ্রুত খোঁজার জন্য
CREATE INDEX idx_tokens_queue ON tokens (doctor_id, token_date, status);
CREATE INDEX idx_appointments_doctor_date ON appointments (doctor_id, appointment_date);

-- নমুনা ডাটা
INSERT INTO departments (name, description) VALUES
('Medicine',   'General medicine'),
('Cardiology', 'Heart department'),
('Eye',        'Eye department');

INSERT INTO users (full_name, email, phone, password_hash, role) VALUES
('Admin User',       'admin@test.com',  '01700000001', 'fake_hash', 'admin'),
('Dr. Rahim',        'rahim@test.com',  '01700000002', 'fake_hash', 'doctor'),
('Dr. Karim',        'karim@test.com',  '01700000003', 'fake_hash', 'doctor'),
('Reception Ayesha', 'ayesha@test.com', '01700000004', 'fake_hash', 'receptionist'),
('Patient Sumon',    'sumon@test.com',  '01700000005', 'fake_hash', 'patient'),
('Patient Nusrat',   'nusrat@test.com', '01700000006', 'fake_hash', 'patient');

INSERT INTO doctors (user_id, department_id, specialization, room_no, avg_consultation_minutes, status) VALUES
(2, 1, 'General Physician', '101', 10, 'available'),
(3, 2, 'Heart Specialist',  '205', 15, 'available');

INSERT INTO doctor_schedules (doctor_id, day_of_week, start_time, end_time, max_patients) VALUES
(1, 0, '09:00', '13:00', 30),
(1, 1, '09:00', '13:00', 30),
(2, 2, '14:00', '18:00', 20);

INSERT INTO appointments (patient_id, doctor_id, appointment_date, appointment_time, reason, status) VALUES
(5, 1, CURRENT_DATE, '09:30', 'Fever and headache', 'checked_in'),
(6, 1, CURRENT_DATE, '09:45', 'Stomach pain',       'booked');

INSERT INTO tokens (appointment_id, patient_id, doctor_id, token_number, qr_code, priority, status, estimated_wait_minutes) VALUES
(1, 5, 1, 1, 'QR-TEST-0001', 'normal', 'waiting', 10),
(2, 6, 1, 2, 'QR-TEST-0002', 'normal', 'waiting', 20);

INSERT INTO delay_logs (doctor_id, delay_minutes, reason) VALUES
(1, 15, 'Emergency patient');

INSERT INTO notifications (user_id, title, message) VALUES
(5, 'Token confirmed', 'Your token number is 1. Estimated wait 10 minutes.');