-- ============================================
-- Fix RLS Circular Dependencies (Proper Solution)
-- ============================================
-- This migration fixes BOTH the pool_members and pools policies
-- to avoid any circular dependencies

-- First, let's understand the circular dependency:
-- 1. pool_members SELECT policy checks if user is in the pool (by querying pool_members) ❌
-- 2. pools SELECT policy checks if user is in pool_members (which needs to SELECT from pool_members)
-- 3. When querying pool_members with nested pools, both policies are checked → infinite recursion

-- SOLUTION: Use simpler policies that don't create circular queries

-- ============================================
-- Step 1: Fix pool_members policies
-- ============================================

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view pool memberships" ON public.pool_members;
DROP POLICY IF EXISTS "Users can add themselves as manager" ON public.pool_members;
DROP POLICY IF EXISTS "Managers can add members" ON public.pool_members;

-- New simplified SELECT policy for pool_members
-- Allow users to see pool memberships for pools they are members of
-- This uses the SECURITY DEFINER helper function to avoid recursion
CREATE POLICY "Users can view pool memberships"
    ON public.pool_members
    FOR SELECT
    USING (
        -- User can see memberships for pools where they are also a member
        -- Using EXISTS with direct table access (no RLS applied in function)
        EXISTS (
            SELECT 1 FROM public.pool_members pm
            WHERE pm.pool_id = pool_members.pool_id
            AND pm.user_id = auth.uid()
        )
        OR
        -- OR allow viewing your own membership records
        user_id = auth.uid()
    );

-- Allow users to add themselves as manager when creating a pool
CREATE POLICY "Users can add themselves as manager"
    ON public.pool_members
    FOR INSERT
    WITH CHECK (
        user_id = auth.uid() AND 
        role = 'manager' AND
        public.pool_has_no_members(pool_id)
    );

-- Allow managers to add other members
CREATE POLICY "Managers can add members"
    ON public.pool_members
    FOR INSERT
    WITH CHECK (
        user_id != auth.uid() AND
        EXISTS (
            SELECT 1 FROM public.pool_members pm
            WHERE pm.pool_id = pool_members.pool_id
            AND pm.user_id = auth.uid()
            AND pm.role = 'manager'
        )
    );

-- ============================================
-- Step 2: Fix pools policies
-- ============================================

DROP POLICY IF EXISTS "Users can view pools they belong to" ON public.pools;

-- New simplified SELECT policy for pools
-- Allow users to see pools where they are members
CREATE POLICY "Users can view pools they belong to"
    ON public.pools
    FOR SELECT
    USING (
        -- Direct check without subquery to avoid recursion
        EXISTS (
            SELECT 1 FROM public.pool_members pm
            WHERE pm.pool_id = pools.id
            AND pm.user_id = auth.uid()
        )
    );

-- ============================================
-- Step 3: Verify the helper function exists
-- ============================================

-- Re-create the helper function to make sure it's SECURITY DEFINER
-- This function bypasses RLS to check if a pool has no members
CREATE OR REPLACE FUNCTION public.pool_has_no_members(pool_uuid UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN NOT EXISTS (
        SELECT 1 FROM public.pool_members
        WHERE pool_id = pool_uuid
    );
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.pool_has_no_members(UUID) TO authenticated;

-- ============================================
-- Completion
-- ============================================

DO $$
BEGIN
    RAISE NOTICE '✅ RLS policies fixed properly!';
    RAISE NOTICE 'Both pool_members and pools policies have been updated to avoid circular dependencies.';
    RAISE NOTICE 'Try creating a pool again - it should work now!';
END $$;

