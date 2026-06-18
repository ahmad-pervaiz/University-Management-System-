import datetime
import psycopg2
import psycopg2.extras

def enroll_student(conn, student_id, course_id, semester_id):
    """
    Registers a student into a course for a given semester.
    Capacity constraints are checked by database-side triggers.
    Returns enrollment_id if successful, or raises Exception if capacity is full.
    """
    try:
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO enrollment (student_id, course_id, semester_id, enrollment_date, status)
                VALUES (%s, %s, %s, %s, %s)
                RETURNING enrollment_id;
            """, (student_id, course_id, semester_id, datetime.date.today(), 'Active'))
            enrollment_id = cur.fetchone()[0]
        conn.commit()
        return enrollment_id
    except psycopg2.DatabaseError as e:
        conn.rollback()
        # Extract original trigger error message if possible
        err_msg = str(e).strip()
        raise Exception(f"Enrollment failed: {err_msg}")
    except Exception as e:
        conn.rollback()
        raise e

def update_enrollment_status(conn, enrollment_id, status):
    """
    Updates enrollment status (e.g. 'Active', 'Dropped', 'Completed').
    Triggers automatically adjust course enrollment counts.
    """
    if status not in ('Active', 'Dropped', 'Completed'):
        raise ValueError("Status must be one of 'Active', 'Dropped', 'Completed'")
        
    try:
        with conn.cursor() as cur:
            cur.execute("""
                UPDATE enrollment
                SET status = %s
                WHERE enrollment_id = %s;
            """, (status, enrollment_id))
        conn.commit()
        return True
    except Exception as e:
        conn.rollback()
        raise e

def get_student_enrollments(conn, student_id):
    """Retrieves all registrations/enrollments for a student."""
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("""
                SELECT e.*, c.course_code, c.course_name, c.credit_hours, s.semester_name
                FROM enrollment e
                JOIN course c ON e.course_id = c.course_id
                JOIN semester s ON e.semester_id = s.semester_id
                WHERE e.student_id = %s
                ORDER BY s.start_date DESC;
            """, (student_id,))
            return cur.fetchall()
    except Exception as e:
        conn.rollback()
        raise e

def get_course_roster(conn, course_id, semester_id):
    """Lists all active students registered in a specific course in a semester."""
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("""
                SELECT e.enrollment_id, e.enrollment_date, s.student_id, s.roll_number, s.first_name, s.last_name, s.email
                FROM enrollment e
                JOIN student s ON e.student_id = s.student_id
                WHERE e.course_id = %s AND e.semester_id = %s AND e.status = 'Active'
                ORDER BY s.roll_number;
            """, (course_id, semester_id))
            return cur.fetchall()
    except Exception as e:
        conn.rollback()
        raise e
