-- ---------------------------------------------------------------------------------------------------

-- 4. The owner wishes to have a report displaying a summary of Orders with their corresponding list of
-- distinct invoices and their total amount grouped by the Supplier Region. The report shall contain
-- the details as per table below ordered by descending Order Total Amount on top region-wise.
-- Implement a Stored Procedure or Function to return the required information.

-- ---------------------------------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE GENERATE_ORDER_SUMMARY_REPORT
IS
    v_cursor SYS_REFCURSOR;
    v_region VARCHAR2(100);
    v_order_reference NUMBER;
    v_order_period VARCHAR2(10);
    v_supplier_name VARCHAR2(255);
    v_order_total_amount VARCHAR2(20);
    v_order_status VARCHAR2(50);
    v_invoice_reference VARCHAR2(100);
    v_invoice_total_amount VARCHAR2(20);
    v_action_status VARCHAR2(50);
BEGIN
    OPEN v_cursor FOR
    SELECT
        s.town AS Region,
        format_order_reference(o.order_ref) AS Order_Reference,
        convert_any_date(o.order_date, 'YYYY-MM') AS Order_Period,
        INITCAP(s.supplier_name) AS Supplier_Name,
        format_total_amount(o.order_total_amount) AS Order_Total_Amount,
        o.order_status,
        i.invoice_reference,
        format_total_amount(SUM(i.invoice_amount)) AS Invoice_Total_Amount,
        CASE 
            WHEN COUNT(CASE WHEN i.invoice_status = 'Pending' THEN 1 END) > 0 THEN 'To follow up'
            WHEN COUNT(CASE WHEN i.invoice_status IS NULL THEN 1 END) > 0 THEN 'To verify'
            ELSE 'No Action'
        END AS Action_Status
    FROM orders o
    JOIN suppliers s ON o.supplier_id = s.supplier_id
    LEFT JOIN invoices i ON o.order_id = i.order_id
    GROUP BY s.town, o.order_ref, o.order_date, s.supplier_name, o.order_total_amount, o.order_status, i.invoice_reference
    ORDER BY s.town, o.order_total_amount DESC;

    LOOP
        FETCH v_cursor INTO v_region, v_order_reference, v_order_period, v_supplier_name, 
                            v_order_total_amount, v_order_status, v_invoice_reference, 
                            v_invoice_total_amount, v_action_status;
        EXIT WHEN v_cursor%NOTFOUND;

        DBMS_OUTPUT.PUT_LINE('Region: ' || v_region || ' | Order Reference: ' || v_order_reference || 
                             ' | Order Period: ' || v_order_period || ' | Supplier: ' || v_supplier_name || 
                             ' | Order Total: ' || v_order_total_amount || ' | Order Status: ' || v_order_status || 
                             ' | Invoice Reference: ' || v_invoice_reference || ' | Invoice Total: ' || v_invoice_total_amount || 
                             ' | Action: ' || v_action_status);
    END LOOP;

    CLOSE v_cursor;
END GENERATE_ORDER_SUMMARY_REPORT;
/

-- ---------------------------------------------------------------------------------------------------

-- Use to run the procedure.

-- ---------------------------------------------------------------------------------------------------
BEGIN
    GENERATE_ORDER_SUMMARY_REPORT;
END;
/