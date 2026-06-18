-- University Management System Automations (Triggers & Functions)

-- 1. Trigger to check course enrollment capacity before enrolling
CREATE OR REPLACE FUNCTION fn_check_enrollment_capacity()
RETURNS TRIGGER AS $$
DECLARE
    v_current INT;
    v_max INT;
BEGIN
    SELECT current_enrollment, max_capacity 
    INTO v_current, v_max 
    FROM course 
    WHERE course_id = NEW.course_id;

    IF v_current >= v_max THEN
        RAISE EXCEPTION 'Course capacity exceeded: Course ID % has reached its maximum capacity of % students.', 
            NEW.course_id, v_max;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_enrollment_capacity ON enrollment;
CREATE TRIGGER trg_check_enrollment_capacity
BEFORE INSERT ON enrollment
FOR EACH ROW
EXECUTE FUNCTION fn_check_enrollment_capacity();


-- 2. Trigger to update course enrollment counts
CREATE OR REPLACE FUNCTION fn_update_enrollment_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- Increment current enrollment if active
        IF NEW.status IN ('Active', 'Completed') THEN
            UPDATE course 
            SET current_enrollment = current_enrollment + 1 
            WHERE course_id = NEW.course_id;
        END IF;
    ELSIF TG_OP = 'DELETE' THEN
        -- Decrement if the deleted record was active
        IF OLD.status IN ('Active', 'Completed') THEN
            UPDATE course 
            SET current_enrollment = GREATEST(0, current_enrollment - 1) 
            WHERE course_id = OLD.course_id;
        END IF;
    ELSIF TG_OP = 'UPDATE' THEN
        -- Handle status transition
        IF OLD.status IN ('Active', 'Completed') AND NEW.status = 'Dropped' THEN
            UPDATE course 
            SET current_enrollment = GREATEST(0, current_enrollment - 1) 
            WHERE course_id = NEW.course_id;
        ELSIF OLD.status = 'Dropped' AND NEW.status IN ('Active', 'Completed') THEN
            UPDATE course 
            SET current_enrollment = current_enrollment + 1 
            WHERE course_id = NEW.course_id;
        END IF;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_enrollment_count ON enrollment;
CREATE TRIGGER trg_update_enrollment_count
AFTER INSERT OR UPDATE OR DELETE ON enrollment
FOR EACH ROW
EXECUTE FUNCTION fn_update_enrollment_count();


-- 3. Trigger to recalculate attendance stats on the enrollment
CREATE OR REPLACE FUNCTION fn_update_attendance_stats()
RETURNS TRIGGER AS $$
DECLARE
    v_enrollment_id INT;
    v_attended INT;
    v_total INT;
    v_percentage NUMERIC(5,2);
BEGIN
    -- Determine which enrollment_id is affected
    IF TG_OP = 'DELETE' THEN
        v_enrollment_id := OLD.enrollment_id;
    ELSE
        v_enrollment_id := NEW.enrollment_id;
    END IF;

    -- Calculate total and attended classes
    SELECT COUNT(*), 
           COUNT(*) FILTER (WHERE status IN ('Present', 'Late'))
    INTO v_total, v_attended
    FROM attendance
    WHERE enrollment_id = v_enrollment_id;

    -- Calculate percentage
    IF v_total > 0 THEN
        v_percentage := ROUND((v_attended::NUMERIC / v_total::NUMERIC) * 100, 2);
    ELSE
        v_percentage := 0.00;
    END IF;

    -- Update enrollment
    UPDATE enrollment
    SET attended_classes = v_attended,
        total_classes = v_total,
        attendance_percentage = v_percentage
    WHERE enrollment_id = v_enrollment_id;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_attendance_stats ON attendance;
CREATE TRIGGER trg_update_attendance_stats
AFTER INSERT OR UPDATE OR DELETE ON attendance
FOR EACH ROW
EXECUTE FUNCTION fn_update_attendance_stats();


-- 4. Trigger to map marks to letter grade & grade points on result insert/update
CREATE OR REPLACE FUNCTION fn_auto_grade_result()
RETURNS TRIGGER AS $$
DECLARE
    v_percentage NUMERIC(5,2);
    v_grade_id INT;
    v_grade_point NUMERIC(3,2);
BEGIN
    -- Compute percentage of marks
    v_percentage := (NEW.marks_obtained / NEW.total_marks) * 100;

    -- Find matching scale
    SELECT grade_id, grade_point 
    INTO v_grade_id, v_grade_point
    FROM grade_scale
    WHERE v_percentage BETWEEN min_marks AND max_marks
    LIMIT 1;

    -- Assign to the result record
    NEW.grade_id := v_grade_id;
    NEW.grade_points := COALESCE(v_grade_point, 0.00);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_auto_grade_result ON result;
CREATE TRIGGER trg_auto_grade_result
BEFORE INSERT OR UPDATE ON result
FOR EACH ROW
EXECUTE FUNCTION fn_auto_grade_result();


-- 5. Trigger to update student CGPA and credits
CREATE OR REPLACE FUNCTION fn_update_student_cgpa()
RETURNS TRIGGER AS $$
DECLARE
    v_enrollment_id INT;
    v_student_id INT;
    v_total_credits INT;
    v_total_points NUMERIC(6,2);
    v_cgpa NUMERIC(3,2);
BEGIN
    -- Get student_id from enrollment
    IF TG_OP = 'DELETE' THEN
        v_enrollment_id := OLD.enrollment_id;
    ELSE
        v_enrollment_id := NEW.enrollment_id;
    END IF;

    SELECT student_id INTO v_student_id FROM enrollment WHERE enrollment_id = v_enrollment_id;

    -- Calculate total completed credits and weighted grade points
    -- Consider only finalized results or results with non-null grade_points
    SELECT COALESCE(SUM(c.credit_hours), 0),
           COALESCE(SUM(r.grade_points * c.credit_hours), 0.00)
    INTO v_total_credits, v_total_points
    FROM result r
    JOIN enrollment e ON r.enrollment_id = e.enrollment_id
    JOIN course c ON e.course_id = c.course_id
    WHERE e.student_id = v_student_id 
      AND r.grade_points IS NOT NULL;

    -- Compute CGPA
    IF v_total_credits > 0 THEN
        v_cgpa := ROUND((v_total_points / v_total_credits)::NUMERIC, 2);
    ELSE
        v_cgpa := 0.00;
    END IF;

    -- Update student record
    UPDATE student
    SET total_credit_hours = v_total_credits,
        total_grade_points = v_total_points,
        cgpa = v_cgpa
    WHERE student_id = v_student_id;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_student_cgpa ON result;
CREATE TRIGGER trg_update_student_cgpa
AFTER INSERT OR UPDATE OR DELETE ON result
FOR EACH ROW
EXECUTE FUNCTION fn_update_student_cgpa();


-- 6. Trigger to automatically assign academic standing on CGPA change
CREATE OR REPLACE FUNCTION fn_update_academic_standing()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.cgpa >= 3.50 THEN
        NEW.academic_standing := 'Excellent';
    ELSIF NEW.cgpa >= 2.50 THEN
        NEW.academic_standing := 'Good';
    ELSIF NEW.cgpa >= 2.00 THEN
        NEW.academic_standing := 'Warning';
    ELSE
        NEW.academic_standing := 'Probation';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_academic_standing ON student;
CREATE TRIGGER trg_update_academic_standing
BEFORE UPDATE OF cgpa ON student
FOR EACH ROW
EXECUTE FUNCTION fn_update_academic_standing();


-- 7. Trigger to regenerate transcript entries for student and semester
CREATE OR REPLACE FUNCTION fn_regenerate_transcript()
RETURNS TRIGGER AS $$
DECLARE
    v_enrollment_id INT;
    v_student_id INT;
    v_semester_id INT;
    v_sem_credits INT;
    v_sem_points NUMERIC(5,2);
    v_sem_gpa NUMERIC(3,2);
    v_current_cgpa NUMERIC(3,2);
    r_record RECORD;
BEGIN
    -- Identify the student and semester
    IF TG_OP = 'DELETE' THEN
        v_enrollment_id := OLD.enrollment_id;
    ELSE
        v_enrollment_id := NEW.enrollment_id;
    END IF;

    SELECT student_id, semester_id 
    INTO v_student_id, v_semester_id 
    FROM enrollment 
    WHERE enrollment_id = v_enrollment_id;

    -- 1. Delete existing transcript entries for this student + semester
    DELETE FROM transcript 
    WHERE student_id = v_student_id AND semester_id = v_semester_id;

    -- 2. Calculate Semester GPA
    SELECT COALESCE(SUM(c.credit_hours), 0),
           COALESCE(SUM(r.grade_points * c.credit_hours), 0.00)
    INTO v_sem_credits, v_sem_points
    FROM result r
    JOIN enrollment e ON r.enrollment_id = e.enrollment_id
    JOIN course c ON e.course_id = c.course_id
    WHERE e.student_id = v_student_id 
      AND e.semester_id = v_semester_id
      AND r.grade_points IS NOT NULL;

    IF v_sem_credits > 0 THEN
        v_sem_gpa := ROUND((v_sem_points / v_sem_credits)::NUMERIC, 2);
    ELSE
        v_sem_gpa := 0.00;
    END IF;

    -- 3. Get student's updated CGPA
    SELECT cgpa INTO v_current_cgpa FROM student WHERE student_id = v_student_id;

    -- 4. Re-insert snapshots for all graded courses in this semester
    FOR r_record IN 
        SELECT c.course_code,
               c.course_name,
               c.credit_hours,
               r.marks_obtained,
               gs.letter_grade,
               r.grade_points
        FROM result r
        JOIN enrollment e ON r.enrollment_id = e.enrollment_id
        JOIN course c ON e.course_id = c.course_id
        LEFT JOIN grade_scale gs ON r.grade_id = gs.grade_id
        WHERE e.student_id = v_student_id 
          AND e.semester_id = v_semester_id
          AND r.grade_points IS NOT NULL
    LOOP
        INSERT INTO transcript (
            student_id, semester_id, course_code, course_name, credit_hours,
            marks, grade, grade_points, semester_gpa, cgpa
        ) VALUES (
            v_student_id, v_semester_id, r_record.course_code, r_record.course_name, r_record.credit_hours,
            r_record.marks_obtained, r_record.letter_grade, r_record.grade_points, v_sem_gpa, v_current_cgpa
        )
        ON CONFLICT (student_id, semester_id, course_code) 
        DO UPDATE SET
            marks = EXCLUDED.marks,
            grade = EXCLUDED.grade,
            grade_points = EXCLUDED.grade_points,
            semester_gpa = EXCLUDED.semester_gpa,
            cgpa = EXCLUDED.cgpa,
            generated_at = CURRENT_TIMESTAMP;
    END LOOP;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_regenerate_transcript ON result;
CREATE TRIGGER trg_regenerate_transcript
AFTER INSERT OR UPDATE OR DELETE ON result
FOR EACH ROW
EXECUTE FUNCTION fn_regenerate_transcript();
