-- ---------------------------------------------------------------------------------------------------

-- 6. List all suppliers with their respective number of orders and total amount ordered from them
-- between the period of 01 January 2024 and 31 August 2024, ordered by number of orders. Output
-- details as per below month-wise. Implement a Stored Procedure or Function to return the required
-- information.

-- ---------------------------------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE GET_SUPPLIER_ORDER_SUMMARY
IS
    CURSOR supplier_cursor IS
        SELECT 
            TO_CHAR(TO_DATE(o.order_date, 'YYYY-MM-DD'), 'Month YYYY') AS order_month,
            s.supplier_name,
            s.contact_name,
            REGEXP_SUBSTR(s.contact_number, '\d{3}-\d{4}') AS contact_no_1,
            REGEXP_SUBSTR(s.contact_number, '\d{4}-\d{4}') AS contact_no_2,
            COUNT(o.order_id) AS total_orders,
            TO_CHAR(SUM(o.order_total_amount), '999,999,990.00') AS order_total_amount
        FROM orders o
        JOIN suppliers s ON o.supplier_id = s.supplier_id
        WHERE o.order_date BETWEEN TO_DATE('2024-01-01', 'YYYY-MM-DD') AND TO_DATE('2024-08-31', 'YYYY-MM-DD')
        GROUP BY TO_CHAR(TO_DATE(o.order_date, 'YYYY-MM-DD'), 'Month YYYY'), s.supplier_name, s.contact_name, s.contact_number
        ORDER BY COUNT(o.order_id) DESC;
    
    v_output VARCHAR2(4000);
    v_order_month VARCHAR2(20);
    v_supplier_name VARCHAR2(100);
    v_contact_name VARCHAR2(100);
    v_contact_no_1 VARCHAR2(10);
    v_contact_no_2 VARCHAR2(10);
    v_total_orders NUMBER;
    v_order_total_amount VARCHAR2(20);
BEGIN
    OPEN supplier_cursor;
    LOOP
        FETCH supplier_cursor INTO v_order_month, v_supplier_name, v_contact_name, v_contact_no_1, v_contact_no_2, v_total_orders, v_order_total_amount;
        EXIT WHEN supplier_cursor%NOTFOUND;
        
        v_output := 'Month: ' || v_order_month || 
                    ' | Supplier Name: ' || v_supplier_name || 
                    ' | Supplier Contact Name: ' || v_contact_name ||
                    ' | Contact No. 1: ' || NVL(v_contact_no_1, 'N/A') || 
                    ' | Contact No. 2: ' || NVL(v_contact_no_2, 'N/A') ||
                    ' | Total Orders: ' || v_total_orders ||
                    ' | Order Total Amount: ' || v_order_total_amount;
        
        DBMS_OUTPUT.PUT_LINE(v_output);
    END LOOP;
    CLOSE supplier_cursor;
END GET_SUPPLIER_ORDER_SUMMARY;
/

-- ---------------------------------------------------------------------------------------------------

-- Use to run the procedure.

-- ---------------------------------------------------------------------------------------------------
BEGIN
    GET_SUPPLIER_ORDER_SUMMARY;
END;
/