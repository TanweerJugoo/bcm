-- ==============================
-- FUNCTION: format_order_reference
-- ==============================
-- Removes 'PO' prefix from order reference and extracts only the numeric value
CREATE OR REPLACE FUNCTION format_order_reference(p_order_ref VARCHAR2) RETURN NUMBER IS
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
/

-- ==============================
-- FUNCTION: format_total_amount
-- ==============================
-- Formats Number as '99,999,990.00'
CREATE OR REPLACE FUNCTION format_total_amount(p_amount VARCHAR2) RETURN VARCHAR2 IS
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
/

-- ==============================
-- FUNCTION: convert_any_date
-- ==============================
-- Converts multiple date formats to 'DD-MON-YYYY' or 'YYYY-MM'
CREATE OR REPLACE FUNCTION convert_any_date(p_date VARCHAR2, p_format VARCHAR2) RETURN VARCHAR2 IS
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
/
