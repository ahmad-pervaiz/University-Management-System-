-- University Management System Indexes

-- 1. Student Indexes
CREATE INDEX IF NOT EXISTS idx_student_dept ON student(dept_id);

-- 2. Teacher Indexes
CREATE INDEX IF NOT EXISTS idx_teacher_dept ON teacher(dept_id);

-- 3. Course Indexes
CREATE INDEX IF NOT EXISTS idx_course_dept ON course(dept_id);
CREATE INDEX IF NOT EXISTS idx_course_teacher ON course(teacher_id);

-- 4. Enrollment Indexes
CREATE INDEX IF NOT EXISTS idx_enrollment_student ON enrollment(student_id);
CREATE INDEX IF NOT EXISTS idx_enrollment_course ON enrollment(course_id);
CREATE INDEX IF NOT EXISTS idx_enrollment_semester ON enrollment(semester_id);
-- Composite index for semester GPA / student transcript lookups
CREATE INDEX IF NOT EXISTS idx_enrollment_composite ON enrollment(student_id, semester_id);

-- 5. Attendance Indexes
CREATE INDEX IF NOT EXISTS idx_attendance_enrollment ON attendance(enrollment_id);
-- Composite index for date-range and student attendance queries
CREATE INDEX IF NOT EXISTS idx_attendance_date ON attendance(enrollment_id, session_date);

-- 6. Transcript Indexes
CREATE INDEX IF NOT EXISTS idx_transcript_student ON transcript(student_id);
-- Composite index for student transcript by semester
CREATE INDEX IF NOT EXISTS idx_transcript_composite ON transcript(student_id, semester_id);

-- 7. Grade Scale Index
-- Range/composite index for mapping marks to letter grades
CREATE INDEX IF NOT EXISTS idx_grade_scale_marks ON grade_scale(min_marks, max_marks);
