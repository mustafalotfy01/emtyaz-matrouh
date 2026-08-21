-- ========================================================
-- VERIFICATION QUERY: تحقق من وجود الجداول
-- ========================================================
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;
