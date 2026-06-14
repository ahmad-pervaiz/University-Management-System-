-- University Management System Schema (PostgreSQL)

-- Drop tables if they exist to allow clean initialization
DROP TABLE IF EXISTS transcript CASCADE;
DROP TABLE IF EXISTS result CASCADE;
DROP TABLE IF EXISTS attendance CASCADE;
DROP TABLE IF EXISTS enrollment CASCADE;
DROP TABLE IF EXISTS grade_scale CASCADE;
DROP TABLE IF EXISTS course CASCADE;
DROP TABLE IF EXISTS semester CASCADE;
DROP TABLE IF EXISTS student CASCADE;
DROP TABLE IF EXISTS teacher CASCADE;
DROP TABLE IF EXISTS department CASCADE;

-- 1. Department Table
CREATE TABLE department (
    dept_id SERIAL PRIMARY KEY,
    dept_name VARCHAR(100) NOT NULL,
    dept_code VARCHAR(10) NOT NULL UNIQUE,
    hod_name VARCHAR(100) NOT NULL
);

-- 2. Teacher Table
CREATE TABLE teacher (
    teacher_id SERIAL PRIMARY KEY,
    dept_id INT NOT NULL REFERENCES department(dept_id) ON DELETE CASCADE,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    hire_date DATE NOT NULL,
    designation VARCHAR(50) NOT NULL CHECK (designation IN ('Lecturer', 'Assistant Professor', 'Associate Professor', 'Professor'))
);

-- 3. Student Table
CREATE TABLE student (
    student_id SERIAL PRIMARY KEY,
    dept_id INT NOT NULL REFERENCES department(dept_id) ON DELETE CASCADE,
    roll_number VARCHAR(20) NOT NULL UNIQUE,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    date_of_birth DATE NOT NULL,
    admission_date DATE NOT NULL,
    cgpa NUMERIC(3,2) DEFAULT 0.00 CHECK (cgpa BETWEEN 0.00 AND 4.00),
    academic_standing VARCHAR(20) DEFAULT 'Good' CHECK (academic_standing IN ('Excellent', 'Good', 'Warning', 'Probation')),
    total_credit_hours INT DEFAULT 0 CHECK (total_credit_hours >= 0),
    total_grade_points NUMERIC(5,2) DEFAULT 0.00 CHECK (total_grade_points >= 0)
);

-- 4. Semester Table
CREATE TABLE semester (
    semester_id SERIAL PRIMARY KEY,
    semester_name VARCHAR(20) NOT NULL UNIQUE, -- e.g. 'Fall 2023', 'Spring 2024'
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    CONSTRAINT chk_semester_dates CHECK (end_date > start_date)
);

-- 5. Course Table
CREATE TABLE course (
    course_id SERIAL PRIMARY KEY,
    dept_id INT NOT NULL REFERENCES department(dept_id) ON DELETE CASCADE,
    teacher_id INT REFERENCES teacher(teacher_id) ON DELETE SET NULL,
    course_code VARCHAR(20) NOT NULL UNIQUE,
    course_name VARCHAR(100) NOT NULL,
    credit_hours INT NOT NULL CHECK (credit_hours BETWEEN 1 AND 6),
    max_capacity INT NOT NULL CHECK (max_capacity > 0),
    current_enrollment INT DEFAULT 0 CHECK (current_enrollment >= 0)
);

-- 6. Grade Scale Table
CREATE TABLE grade_scale (
    grade_id SERIAL PRIMARY KEY,
    letter_grade VARCHAR(5) NOT NULL UNIQUE,
    min_marks NUMERIC(5,2) NOT NULL CHECK (min_marks >= 0),
    max_marks NUMERIC(5,2) NOT NULL CHECK (max_marks >= min_marks),
    grade_point NUMERIC(3,2) NOT NULL CHECK (grade_point BETWEEN 0.00 AND 4.00)
);

-- 7. Enrollment Table
CREATE TABLE enrollment (
    enrollment_id SERIAL PRIMARY KEY,
    student_id INT NOT NULL REFERENCES student(student_id) ON DELETE CASCADE,
    course_id INT NOT NULL REFERENCES course(course_id) ON DELETE CASCADE,
    semester_id INT NOT NULL REFERENCES semester(semester_id) ON DELETE CASCADE,
    enrollment_date DATE NOT NULL,
    status VARCHAR(15) DEFAULT 'Active' CHECK (status IN ('Active', 'Dropped', 'Completed')),
    -- Attendance summary columns (calculated by triggers)
    attended_classes INT DEFAULT 0 CHECK (attended_classes >= 0),
    total_classes INT DEFAULT 0 CHECK (total_classes >= 0),
    attendance_percentage NUMERIC(5,2) DEFAULT 0.00 CHECK (attendance_percentage BETWEEN 0.00 AND 100.00),
    CONSTRAINT uq_enrollment UNIQUE (student_id, course_id, semester_id)
);

-- 8. Attendance Table
CREATE TABLE attendance (
    attendance_id SERIAL PRIMARY KEY,
    enrollment_id INT NOT NULL REFERENCES enrollment(enrollment_id) ON DELETE CASCADE,
    session_date DATE NOT NULL,
    status VARCHAR(15) NOT NULL CHECK (status IN ('Present', 'Absent', 'Late', 'Excused')),
    CONSTRAINT uq_attendance UNIQUE (enrollment_id, session_date)
);

-- 9. Result Table
CREATE TABLE result (
    result_id SERIAL PRIMARY KEY,
    enrollment_id INT NOT NULL UNIQUE REFERENCES enrollment(enrollment_id) ON DELETE CASCADE,
    marks_obtained NUMERIC(5,2) NOT NULL,
    total_marks NUMERIC(5,2) DEFAULT 100.00 CHECK (total_marks > 0),
    grade_id INT REFERENCES grade_scale(grade_id) ON DELETE SET NULL,
    grade_points NUMERIC(3,2), -- copies grade_scale.grade_point
    is_finalized BOOLEAN DEFAULT FALSE,
    CONSTRAINT chk_marks CHECK (marks_obtained BETWEEN 0.00 AND total_marks)
);

-- 10. Transcript Table (Materialized Snapshot per student course semester)
CREATE TABLE transcript (
    transcript_id SERIAL PRIMARY KEY,
    student_id INT NOT NULL REFERENCES student(student_id) ON DELETE CASCADE,
    semester_id INT NOT NULL REFERENCES semester(semester_id) ON DELETE CASCADE,
    course_code VARCHAR(20) NOT NULL,
    course_name VARCHAR(100) NOT NULL,
    credit_hours INT NOT NULL,
    marks NUMERIC(5,2) NOT NULL,
    grade VARCHAR(5) NOT NULL,
    grade_points NUMERIC(3,2) NOT NULL,
    semester_gpa NUMERIC(3,2) NOT NULL,
    cgpa NUMERIC(3,2) NOT NULL,
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_transcript UNIQUE (student_id, semester_id, course_code)
);
