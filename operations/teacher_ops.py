import psycopg2
import psycopg2.extras

def add_teacher(conn, dept_id, first_name, last_name, email, hire_date, designation):
    """Inserts a new teacher record. Returns teacher_id."""
    try:
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO teacher (dept_id, first_name, last_name, email, hire_date, designation)
                VALUES (%s, %s, %s, %s, %s, %s)
                RETURNING teacher_id;
            """, (dept_id, first_name, last_name, email, hire_date, designation))
            teacher_id = cur.fetchone()[0]
        conn.commit()
        return teacher_id
    except Exception as e:
        conn.rollback()
        raise e

def assign_course(conn, teacher_id, course_id):
    """Assigns a teacher to teach a specific course."""
    try:
        with conn.cursor() as cur:
            cur.execute("""
                UPDATE course
                SET teacher_id = %s
                WHERE course_id = %s;
            """, (teacher_id, course_id))
        conn.commit()
        return True
    except Exception as e:
        conn.rollback()
        raise e

def view_teacher(conn, teacher_id):
    """Fetches teacher profile details including department name."""
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("""
                SELECT t.*, d.dept_name, d.dept_code
                FROM teacher t
                JOIN department d ON t.dept_id = d.dept_id
                WHERE t.teacher_id = %s;
            """, (teacher_id,))
            return cur.fetchone()
    except Exception as e:
        conn.rollback()
        raise e

def get_teacher_schedule(conn, teacher_id):
    """Lists all courses currently assigned to a teacher."""
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("""
                SELECT course_id, course_code, course_name, credit_hours, max_capacity, current_enrollment
                FROM course
                WHERE teacher_id = %s;
            """, (teacher_id,))
            return cur.fetchall()
    except Exception as e:
        conn.rollback()
        raise e
