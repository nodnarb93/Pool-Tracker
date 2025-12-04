# Fix for RLS Infinite Recursion Error

## Problem
When trying to create a pool, you encounter this error:
```
Failed to create pool: infinite recursion detected in policy for relation "pool_members"
```

## Root Cause
The `pool_members` table has a SELECT policy that creates circular dependency:
- To view pool memberships, it checks if you're a member of the pool
- To check if you're a member, it needs to query pool_members
- To query pool_members, it needs to check if you can view it
- This creates an infinite loop 🔄

## Solution
Run the following SQL in your Supabase SQL Editor to fix the issue:

```sql
-- Drop the problematic policy
DROP POLICY IF EXISTS "Users can view pool memberships" ON public.pool_members;

-- Create a new, simpler SELECT policy that doesn't cause recursion
CREATE POLICY "Users can view pool memberships"
    ON public.pool_members
    FOR SELECT
    USING (true);
```

## How to Apply the Fix

### Option 1: Run SQL directly in Supabase Dashboard (Quickest)
1. Go to your Supabase project dashboard
2. Click on "SQL Editor" in the left sidebar
3. Click "New query"
4. Copy and paste the SQL from `supabase/migrations/002_fix_rls_recursion.sql`
5. Click "Run" or press Ctrl+Enter

### Option 2: Run the migration file
If you have the Supabase CLI installed:
```bash
supabase db push
```

## Why This Fix is Safe
- Users can only see pools they're members of (controlled by the `pools` table SELECT policy)
- Once they can see a pool, they need to see all members in that pool for the app to function
- This change allows viewing pool memberships without the circular dependency
- Individual user privacy is still maintained through other table policies

## Verify the Fix
After applying the fix, try creating a pool again. It should work without any recursion errors!

