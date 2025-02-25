CREATE OR REPLACE PACKAGE BCM_ORDER_MGMT_PKG AS
    PROCEDURE MIGRATE_BCM_ORDER_MGT;
    PROCEDURE GENERATE_ORDER_SUMMARY_REPORT;
    PROCEDURE GET_MEDIAN_ORDER_DETAILS;
    PROCEDURE GET_SUPPLIER_ORDER_SUMMARY;
    FUNCTION FORMAT_ORDER_REFERENCE(p_order_ref VARCHAR2) RETURN NUMBER;
    FUNCTION FORMAT_TOTAL_AMOUNT(p_amount VARCHAR2) RETURN VARCHAR2;
    FUNCTION CONVERT_ANY_DATE(p_date VARCHAR2, p_format VARCHAR2) RETURN VARCHAR2;
END BCM_ORDER_MGMT_PKG;
/

CREATE OR REPLACE PACKAGE BODY BCM_ORDER_MGMT_PKG AS

    -- ==============================
    -- FUNCTION: format_order_reference
    -- ==============================
    -- Removes 'PO' prefix from order reference and extracts only the numeric value
    FUNCTION format_order_reference(p_order_ref VARCHAR2) RETURN NUMBER IS
        v_numeric_part NUMBER;
    BEGIN
        BEGIN
            v_numeric_part := TO_NUMBER(REGEXP_REPLACE(p_order_ref, '[^0-9]', ''));
        EXCEPTION
            WHEN VALUE_ERROR THEN
                DBMS_OUTPUT.PUT_LINE('Invalid Order Reference: ' || p_order_ref);
                RETURN NULL;
        END;
        RETURN v_numeric_part;
    END format_order_reference;

  
    -- ==============================
    -- FUNCTION: format_total_amount
    -- ==============================
    -- Formats Number as '99,999,990.00'
    FUNCTION format_total_amount(p_amount VARCHAR2) RETURN VARCHAR2 IS
        v_formatted_amount VARCHAR2(20);
    BEGIN
        BEGIN
            v_formatted_amount := TO_CHAR(TO_NUMBER(p_amount), '999,999,990.00');
        EXCEPTION
            WHEN VALUE_ERROR THEN
                DBMS_OUTPUT.PUT_LINE('Invalid Amount: ' || p_amount);
                RETURN NULL;
        END;
        RETURN v_formatted_amount;
    END format_total_amount;


    -- ==============================
    -- FUNCTION: convert_any_date
    -- ==============================
    -- Converts multiple date formats to 'DD-MON-YYYY' or 'YYYY-MM'
    FUNCTION convert_any_date(p_date VARCHAR2, p_format VARCHAR2) RETURN VARCHAR2 IS
        v_date DATE;
        v_formatted_date VARCHAR2(20);
    BEGIN
        BEGIN
            v_date := TO_DATE(p_date, 'DD-MM-YYYY');
        EXCEPTION
            WHEN OTHERS THEN
                BEGIN
                    v_date := TO_DATE(p_date, 'DD-MON-YYYY');
                EXCEPTION
                    WHEN OTHERS THEN
                        BEGIN
                            v_date := TO_DATE(p_date, 'YYYY-MM-DD');
                        EXCEPTION
                            WHEN OTHERS THEN
                                DBMS_OUTPUT.PUT_LINE('Invalid Date Format: ' || p_date);
                                RETURN NULL;
                        END;
                END;
        END;

        IF p_format = 'DD-MON-YYYY' THEN
            v_formatted_date := TO_CHAR(v_date, 'DD-MON-YYYY');
        ELSIF p_format = 'YYYY-MM' THEN
            v_formatted_date := TO_CHAR(v_date, 'YYYY-MM');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Invalid Format Specifier: ' || p_format);
            RETURN NULL;
        END IF;

        RETURN v_formatted_date;
    END convert_any_date;


    -- ---------------------------------------------------------------------------------------------------
    -- 3. Develop a SQL procedure to trigger a migration process that will extract information from table
    -- "BCM_ORDER_MGT" and load them in tables that you created with proper data format. 
    -- ---------------------------------------------------------------------------------------------------
    PROCEDURE MIGRATE_BCM_ORDER_MGT
    IS
        v_supplier_id suppliers.supplier_id%TYPE;
        v_order_id orders.order_id%TYPE;
        v_address_part VARCHAR2(200);
        v_town VARCHAR2(100);
        v_country VARCHAR2(100);
        v_order_total NUMBER;
        v_order_line_amount NUMBER;
        v_invoice_amount NUMBER;
        v_order_ref VARCHAR2(50);
    BEGIN
        FOR r IN (SELECT * FROM BCM_ORDER_MGT) LOOP
            BEGIN
                v_address_part := TRIM(REGEXP_SUBSTR(r.supp_address, '^([^,]+,[^,]+,[^,]+)', 1, 1, NULL, 1));
                v_town := TRIM(REGEXP_SUBSTR(r.supp_address, '[^,]+', 1, 4));
                v_country := TRIM(REGEXP_SUBSTR(r.supp_address, '[^,]+', 1, 5));

                v_address_part := REPLACE(v_address_part, '-', '');
                v_address_part := REPLACE(v_address_part, ',', '');

                BEGIN
                    SELECT supplier_id INTO v_supplier_id
                    FROM suppliers
                    WHERE supplier_name = r.supplier_name;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        INSERT INTO suppliers (supplier_name, contact_name, address, town, country, contact_number, email)
                        VALUES (r.supplier_name, r.supp_contact_name, v_address_part, v_town, v_country, r.supp_contact_number, r.supp_email)
                        RETURNING supplier_id INTO v_supplier_id;
                END;

                BEGIN
                    v_order_ref := format_order_reference(r.order_ref);
                EXCEPTION
                    WHEN OTHERS THEN
                        DBMS_OUTPUT.PUT_LINE('Invalid Order Reference: ' || r.order_ref);
                        v_order_ref := NULL;
                END;

                BEGIN
                    v_order_total := TO_NUMBER(REGEXP_REPLACE(r.order_total_amount, '[^0-9.]', ''));
                EXCEPTION
                    WHEN VALUE_ERROR THEN
                        DBMS_OUTPUT.PUT_LINE('Invalid Order Total Amount: ' || r.order_total_amount);
                        v_order_total := NULL;
                END;

                INSERT INTO orders (
                    supplier_id, order_ref, order_date, order_total_amount, 
                    order_description, order_status
                )
                VALUES (
                    v_supplier_id, v_order_ref, 
                    convert_any_date(r.order_date, 'DD-MON-YYYY'), 
                    v_order_total, r.order_description, 
                    r.order_status
                )
                RETURNING order_id INTO v_order_id;

                BEGIN
                    v_order_line_amount := TO_NUMBER(REGEXP_REPLACE(r.order_line_amount, '[^0-9.]', ''));
                EXCEPTION
                    WHEN VALUE_ERROR THEN
                        DBMS_OUTPUT.PUT_LINE('Invalid Order Line Amount: ' || r.order_line_amount);
                        v_order_line_amount := NULL;
                END;

                IF v_order_line_amount IS NOT NULL THEN
                    INSERT INTO order_items (order_id, item_description, item_amount)
                    VALUES (v_order_id, r.order_description, v_order_line_amount);
                END IF;

                BEGIN
                    v_invoice_amount := TO_NUMBER(REGEXP_REPLACE(r.invoice_amount, '[^0-9.]', ''));
                EXCEPTION
                    WHEN VALUE_ERROR THEN
                        DBMS_OUTPUT.PUT_LINE('Invalid Invoice Amount: ' || r.invoice_amount);
                        v_invoice_amount := NULL;
                END;

                IF r.invoice_reference IS NOT NULL THEN
                    INSERT INTO invoices (
                        order_id, invoice_reference, invoice_date, invoice_status, 
                        invoice_hold_reason, invoice_amount, invoice_description
                    )
                    VALUES (
                        v_order_id, r.invoice_reference, 
                        convert_any_date(r.invoice_date, 'DD-MON-YYYY'), 
                        r.invoice_status, r.invoice_hold_reason, 
                        v_invoice_amount, 
                        r.invoice_description
                    );
                END IF;

            END LOOP;
        END LOOP;

        COMMIT;
    END MIGRATE_BCM_ORDER_MGT;
    

    -- ---------------------------------------------------------------------------------------------------
    -- 4. The owner wishes to have a report displaying a summary of Orders with their corresponding list of
    -- distinct invoices and their total amount grouped by the Supplier Region. The report shall contain
    -- the details as per table below ordered by descending Order Total Amount on top region-wise.
    -- Implement a Stored Procedure or Function to return the required information.
    -- ---------------------------------------------------------------------------------------------------
    PROCEDURE GENERATE_ORDER_SUMMARY_REPORT
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


    -- ---------------------------------------------------------------------------------------------------
    -- 5. Return details for the median value of the Order Total Amount from the list. Only one record is
    -- expected with the following information. Implement a Stored Procedure or Function to return the
    -- required information.
    -- ---------------------------------------------------------------------------------------------------
   PROCEDURE GET_MEDIAN_ORDER_DETAILS
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


    -- ---------------------------------------------------------------------------------------------------
    -- 6. List all suppliers with their respective number of orders and total amount ordered from them
    -- between the period of 01 January 2024 and 31 August 2024, ordered by number of orders. Output
    -- details as per below month-wise. Implement a Stored Procedure or Function to return the required
    -- information.
    -- ---------------------------------------------------------------------------------------------------
   PROCEDURE GET_SUPPLIER_ORDER_SUMMARY
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
    

END BCM_ORDER_MGMT_PKG;
