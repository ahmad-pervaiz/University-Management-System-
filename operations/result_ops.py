import psycopg2
from psycopg2.extras import execute_values

def submit_result(conn, enrollment_id, marks_obtained, total_marks=100.0, is_finalized=False):
    """
    Submits or updates a course result.
    All grading scales, GPA, student CGPA, standing, and transcript regeneration
    cascade automatically via database triggers.
    """
    try:
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO result (enrollment_id, marks_obtained, total_marks, is_finalized)
                VALUES (%s, %s, %s, %s)
                ON CONFLICT (enrollment_id) 
                DO UPDATE SET 
                    marks_obtained = EXCLUDED.marks_obtained,
                    total_marks = EXCLUDED.total_marks,
                    is_finalized = EXCLUDED.is_finalized
                RETURNING result_id;
            """, (enrollment_id, marks_obtained, total_marks, is_finalized))
            result_id = cur.fetchone()[0]
        conn.commit()
        return result_id
    except Exception as e:
        conn.rollback()
        raise e

def submit_bulk_results(conn, results_list):
    """
    Submits results in bulk.
    results_list: List of tuples (enrollment_id, marks_obtained, total_marks, is_finalized)
    """
    try:
        with conn.cursor() as cur:
            execute_values(
                cur,
                """
                INSERT INTO result (enrollment_id, marks_obtained, total_marks, is_finalized)
                VALUES %s
                ON CONFLICT (enrollment_id) 
                DO UPDATE SET 
                    marks_obtained = EXCLUDED.marks_obtained,
                    total_marks = EXCLUDED.total_marks,
                    is_finalized = EXCLUDED.is_finalized;
                """,
                results_list
            )
        conn.commit()
        return True
    except Exception as e:
        conn.rollback()
        raise e

def get_result_details(conn, enrollment_id):
    """Fetches result grading details for an enrollment."""
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("""
                SELECT r.*, gs.letter_grade, gs.grade_point
                FROM result r
                LEFT JOIN grade_scale gs ON r.grade_id = gs.grade_id
                WHERE r.enrollment_id = %s;
            """, (enrollment_id,))
            return cur.fetchone()
    except Exception as e:
        conn.rollback()
        raise e
