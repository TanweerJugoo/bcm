-- ---------------------------------------------------------------------------------------------------

-- 5. Return details for the median value of the Order Total Amount from the list. Only one record is
-- expected with the following information. Implement a Stored Procedure or Function to return the
-- required information.

-- ---------------------------------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE GET_MEDIAN_ORDER_DETAILS
IS
    v_median_amount NUMBER;
    v_order_id orders.order_id%TYPE;
    v_order_ref VARCHAR2(50);
    v_order_date VARCHAR2(20);
    v_supplier_name VARCHAR2(100);
    v_order_total_amount VARCHAR2(20);
    v_order_status VARCHAR2(50);
    v_invoice_references VARCHAR2(4000);
BEGIN
    SELECT MEDIAN(order_total_amount) INTO v_median_amount FROM orders;

    SELECT order_total_amount INTO v_median_amount
    FROM orders
    WHERE ABS(order_total_amount - v_median_amount) = (
        SELECT MIN(ABS(order_total_amount - v_median_amount)) FROM orders
    )
    FETCH FIRST 1 ROW ONLY;

    SELECT o.order_id, 
           format_order_reference(o.order_ref) AS order_ref, 
           convert_any_date(o.order_date, 'DD-MON-YYYY') AS order_date, 
           INITCAP(s.supplier_name) AS Supplier_Name,
           format_total_amount(o.order_total_amount) AS order_total_amount,
           o.order_status
    INTO v_order_id, v_order_ref, v_order_date, v_supplier_name, v_order_total_amount, v_order_status
    FROM orders o
    JOIN suppliers s ON o.supplier_id = s.supplier_id
    WHERE o.order_total_amount = v_median_amount
    AND ROWNUM = 1;

    SELECT LISTAGG(i.invoice_reference, '|') WITHIN GROUP (ORDER BY i.invoice_reference)
    INTO v_invoice_references
    FROM invoices i
    WHERE i.order_id = v_order_id;

    DBMS_OUTPUT.PUT_LINE('Order Reference: ' || v_order_ref);
    DBMS_OUTPUT.PUT_LINE('Order Date: ' || v_order_date);
    DBMS_OUTPUT.PUT_LINE('Supplier Name: ' || v_supplier_name);
    DBMS_OUTPUT.PUT_LINE('Order Total Amount: ' || v_order_total_amount);
    DBMS_OUTPUT.PUT_LINE('Order Status: ' || v_order_status);
    DBMS_OUTPUT.PUT_LINE('Invoice References: ' || NVL(v_invoice_references, 'No Invoices'));

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('No order found near the median order total amount.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END GET_MEDIAN_ORDER_DETAILS;
/

-- ---------------------------------------------------------------------------------------------------

-- Use to run the procedure.

-- ---------------------------------------------------------------------------------------------------
BEGIN
    GET_MEDIAN_ORDER_DETAILS;
END;
/