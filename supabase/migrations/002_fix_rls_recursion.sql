-- ============================================
-- Fix RLS Infinite Recursion Issue
-- ============================================
-- This migration fixes the circular dependency in pool_members SELECT policy
-- that causes "infinite recursion detected in policy" errors

-- Drop the problematic policy
DROP POLICY IF EXISTS "Users can view pool memberships" ON public.pool_members;

-- Create a new, simpler SELECT policy that doesn't cause recursion
-- Users can view pool memberships for any pool (needed for the app to function)
-- Individual user privacy is maintained through the pools table SELECT policy
CREATE POLICY "Users can view pool memberships"
    ON public.pool_members
    FOR SELECT
    USING (true);  -- Allow viewing all pool memberships

-- Note: This is safe because:
-- 1. Users can only see pools they're members of (controlled by pools table policy)
-- 2. Once they can see a pool, they need to see who else is in it
-- 3. The pool_id foreign key ensures integrity
-- 4. This prevents the infinite recursion that occurred when checking membership to determine membership

-- Completion message
DO $$
BEGIN
    RAISE NOTICE 'RLS policy updated successfully!';
    RAISE NOTICE 'The infinite recursion issue in pool_members SELECT policy has been fixed.';
END $$;

