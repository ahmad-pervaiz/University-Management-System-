import psycopg2
import psycopg2.extras

def generate_transcript(conn, student_id):
    """
    Retrieves the entire flat, materialized transcript history for a student.
    Ordered chronologically by semester.
    """
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("""
                SELECT t.*, s.semester_name
                FROM transcript t
                JOIN semester s ON t.semester_id = s.semester_id
                WHERE t.student_id = %s
                ORDER BY s.start_date ASC, t.course_code ASC;
            """, (student_id,))
            return cur.fetchall()
    except Exception as e:
        conn.rollback()
        raise e

def generate_semester_transcript(conn, student_id, semester_id):
    """
    Retrieves the flat transcript records for a student for a single semester.
    """
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("""
                SELECT t.*, s.semester_name
                FROM transcript t
                JOIN semester s ON t.semester_id = s.semester_id
                WHERE t.student_id = %s AND t.semester_id = %s
                ORDER BY t.course_code ASC;
            """, (student_id, semester_id))
            return cur.fetchall()
    except Exception as e:
        conn.rollback()
        raise e

def get_student_summary(conn, student_id):
    """Retrieves quick summary details of student academic progress."""
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("""
                SELECT student_id, roll_number, first_name, last_name, cgpa, academic_standing, 
                       total_credit_hours, total_grade_points
                FROM student
                WHERE student_id = %s;
            """, (student_id,))
            return cur.fetchone()
    except Exception as e:
        conn.rollback()
        raise e
