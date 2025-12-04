-- ============================================
-- SIMPLE RLS POLICIES FOR EARLY DEVELOPMENT
-- ============================================
-- This replaces all the complex policies with simple ones:
-- "If you're logged in, you can do things"
-- We'll add proper security later when the app actually works!

-- ============================================
-- Drop ALL existing policies
-- ============================================

-- Users table
DROP POLICY IF EXISTS "Users can read own profile" ON public.users;
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
DROP POLICY IF EXISTS "Users can read other profiles" ON public.users;

-- Pools table
DROP POLICY IF EXISTS "Users can view pools they belong to" ON public.pools;
DROP POLICY IF EXISTS "Authenticated users can create pools" ON public.pools;
DROP POLICY IF EXISTS "Managers can update pools" ON public.pools;

-- Pool members table
DROP POLICY IF EXISTS "Users can view pool memberships" ON public.pool_members;
DROP POLICY IF EXISTS "Users can add themselves as manager" ON public.pool_members;
DROP POLICY IF EXISTS "Managers can add members" ON public.pool_members;
DROP POLICY IF EXISTS "Managers can update memberships" ON public.pool_members;
DROP POLICY IF EXISTS "Users can leave pools" ON public.pool_members;

-- Contestants table
DROP POLICY IF EXISTS "Users can view contestants in their pools" ON public.contestants;
DROP POLICY IF EXISTS "Managers can add contestants" ON public.contestants;
DROP POLICY IF EXISTS "Managers can update contestants" ON public.contestants;
DROP POLICY IF EXISTS "Managers can delete contestants" ON public.contestants;

-- Parameters table
DROP POLICY IF EXISTS "Users can view parameters in their pools" ON public.parameters;
DROP POLICY IF EXISTS "Managers can create parameters" ON public.parameters;
DROP POLICY IF EXISTS "Managers can update parameters" ON public.parameters;
DROP POLICY IF EXISTS "Managers can delete parameters" ON public.parameters;

-- Votes table
DROP POLICY IF EXISTS "Users can view votes in their pools" ON public.votes;
DROP POLICY IF EXISTS "Users can submit votes for open parameters" ON public.votes;
DROP POLICY IF EXISTS "Users can update own votes" ON public.votes;
DROP POLICY IF EXISTS "Users can delete own votes" ON public.votes;

-- Correct answers table
DROP POLICY IF EXISTS "Users can view correct answers in their pools" ON public.correct_answers;
DROP POLICY IF EXISTS "Managers can enter correct answers" ON public.correct_answers;
DROP POLICY IF EXISTS "Managers can update correct answers" ON public.correct_answers;

-- Pool scores table
DROP POLICY IF EXISTS "Users can view scores in their pools" ON public.pool_scores;

-- ============================================
-- Create SIMPLE policies
-- ============================================
-- For development: If you're authenticated, you can do it
-- Add proper security later when everything works!

-- USERS TABLE - Simple policies
CREATE POLICY "authenticated_users_all" ON public.users
    FOR ALL USING (auth.uid() IS NOT NULL)
    WITH CHECK (auth.uid() IS NOT NULL);

-- POOLS TABLE - Simple policies
CREATE POLICY "authenticated_users_all" ON public.pools
    FOR ALL USING (auth.uid() IS NOT NULL)
    WITH CHECK (auth.uid() IS NOT NULL);

-- POOL MEMBERS TABLE - Simple policies
CREATE POLICY "authenticated_users_all" ON public.pool_members
    FOR ALL USING (auth.uid() IS NOT NULL)
    WITH CHECK (auth.uid() IS NOT NULL);

-- CONTESTANTS TABLE - Simple policies
CREATE POLICY "authenticated_users_all" ON public.contestants
    FOR ALL USING (auth.uid() IS NOT NULL)
    WITH CHECK (auth.uid() IS NOT NULL);

-- PARAMETERS TABLE - Simple policies
CREATE POLICY "authenticated_users_all" ON public.parameters
    FOR ALL USING (auth.uid() IS NOT NULL)
    WITH CHECK (auth.uid() IS NOT NULL);

-- VOTES TABLE - Simple policies
CREATE POLICY "authenticated_users_all" ON public.votes
    FOR ALL USING (auth.uid() IS NOT NULL)
    WITH CHECK (auth.uid() IS NOT NULL);

-- CORRECT ANSWERS TABLE - Simple policies
CREATE POLICY "authenticated_users_all" ON public.correct_answers
    FOR ALL USING (auth.uid() IS NOT NULL)
    WITH CHECK (auth.uid() IS NOT NULL);

-- POOL SCORES TABLE - Simple policies
CREATE POLICY "authenticated_users_all" ON public.pool_scores
    FOR ALL USING (auth.uid() IS NOT NULL)
    WITH CHECK (auth.uid() IS NOT NULL);

-- ============================================
-- Done!
-- ============================================

DO $$
BEGIN
    RAISE NOTICE '✅ Simple RLS policies applied!';
    RAISE NOTICE '🎯 Any authenticated user can now do anything';
    RAISE NOTICE '⚠️  Add proper security later when the app works!';
    RAISE NOTICE '';
    RAISE NOTICE 'Try creating a pool now - it should just work!';
END $$;

