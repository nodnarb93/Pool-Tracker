-- ============================================
-- Verification Queries
-- ============================================
-- Run these queries after running the migration
-- to verify everything was set up correctly
-- ============================================

-- Check all tables exist
SELECT 
    table_name,
    table_schema
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN (
    'users', 'pools', 'pool_members', 'contestants', 
    'parameters', 'votes', 'correct_answers', 'pool_scores'
  )
ORDER BY table_name;

-- Check RLS is enabled on all tables
SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (
    'users', 'pools', 'pool_members', 'contestants', 
    'parameters', 'votes', 'correct_answers', 'pool_scores'
  )
ORDER BY tablename;

-- Count RLS policies per table
SELECT 
    schemaname,
    tablename,
    COUNT(*) as policy_count
FROM pg_policies
WHERE schemaname = 'public'
GROUP BY schemaname, tablename
ORDER BY tablename;

-- Check triggers exist
SELECT 
    trigger_name,
    event_object_table as table_name,
    action_timing,
    event_manipulation
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;

-- Check indexes exist
SELECT 
    tablename,
    indexname
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN (
    'users', 'pools', 'pool_members', 'contestants', 
    'parameters', 'votes', 'correct_answers', 'pool_scores'
  )
ORDER BY tablename, indexname;

-- Check functions exist
SELECT 
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN (
    'handle_new_user',
    'update_updated_at_column',
    'set_parameter_scored',
    'update_pool_scores',
    'initialize_pool_scores',
    'initialize_member_scores'
  )
ORDER BY routine_name;

-- Expected Results:
-- - 8 tables should exist
-- - All 8 tables should have RLS enabled (rowsecurity = true)
-- - Multiple policies should exist (at least 2-3 per table)
-- - Multiple triggers should exist
-- - Multiple indexes should exist
-- - 6 functions should exist

