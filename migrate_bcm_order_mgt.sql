-- ---------------------------------------------------------------------------------------------------

-- 3. Develop a SQL procedure to trigger a migration process that will extract information from table
-- "BCM_ORDER_MGT" and load them in tables that you created with proper data format. 

-- ---------------------------------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE MIGRATE_BCM_ORDER_MGT
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
/

-- ---------------------------------------------------------------------------------------------------

-- Use to run the procedure.

-- ---------------------------------------------------------------------------------------------------
BEGIN
    MIGRATE_BCM_ORDER_MGT;
END;
/