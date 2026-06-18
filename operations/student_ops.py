import psycopg2
import psycopg2.extras

def add_student(conn, dept_id, roll_number, first_name, last_name, email, date_of_birth, admission_date):
    """
    Inserts a new student record.
    Returns the newly created student_id.
    """
    try:
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO student (dept_id, roll_number, first_name, last_name, email, date_of_birth, admission_date)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                RETURNING student_id;
            """, (dept_id, roll_number, first_name, last_name, email, date_of_birth, admission_date))
            student_id = cur.fetchone()[0]
        conn.commit()
        return student_id
    except Exception as e:
        conn.rollback()
        raise e

def update_student(conn, student_id, **fields):
    """
    Dynamically updates a student's profile.
    Only allows editing mutable profile fields, not trigger-controlled metrics.
    """
    allowed_fields = {
        "dept_id", "roll_number", "first_name", "last_name", 
        "email", "date_of_birth", "admission_date"
    }
    
    update_parts = []
    params = []
    
    for key, val in fields.items():
        if key in allowed_fields:
            update_parts.append(f"{key} = %s")
            params.append(val)
            
    if not update_parts:
        return False
        
    params.append(student_id)
    query = f"UPDATE student SET {', '.join(update_parts)} WHERE student_id = %s"
    
    try:
        with conn.cursor() as cur:
            cur.execute(query, params)
        conn.commit()
        return True
    except Exception as e:
        conn.rollback()
        raise e

def view_student(conn, student_id):
    """
    Returns student profile details, including department details,
    academic standing, and trigger-maintained metrics.
    """
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("""
                SELECT s.*, d.dept_name, d.dept_code
                FROM student s
                JOIN department d ON s.dept_id = d.dept_id
                WHERE s.student_id = %s;
            """, (student_id,))
            return cur.fetchone()
    except Exception as e:
        conn.rollback()
        raise e

def list_students(conn, limit=100, offset=0):
    """Utility to list students in bulk."""
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("""
                SELECT s.student_id, s.roll_number, s.first_name, s.last_name, s.email, 
                       s.cgpa, s.academic_standing, d.dept_code
                FROM student s
                JOIN department d ON s.dept_id = d.dept_id
                ORDER BY s.roll_number
                LIMIT %s OFFSET %s;
            """, (limit, offset))
            return cur.fetchall()
    except Exception as e:
        conn.rollback()
        raise e
