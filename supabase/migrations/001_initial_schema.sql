-- ============================================
-- Pool Tracker Database Schema
-- ============================================
-- This migration creates all tables, RLS policies, and triggers
-- Run this in your Supabase SQL Editor
-- ============================================

-- Enable UUID extension (usually enabled by default in Supabase)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- STEP 1: CREATE ALL TABLES
-- ============================================

-- 1. USERS TABLE
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT UNIQUE NOT NULL,
    display_name TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

-- 2. POOLS TABLE
CREATE TABLE IF NOT EXISTS public.pools (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'archived')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

-- 3. POOL MEMBERS TABLE
CREATE TABLE IF NOT EXISTS public.pool_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pool_id UUID NOT NULL REFERENCES public.pools(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('manager', 'member')),
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    UNIQUE (pool_id, user_id)
);

-- 4. CONTESTANTS TABLE
CREATE TABLE IF NOT EXISTS public.contestants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pool_id UUID NOT NULL REFERENCES public.pools(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    eliminated_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

-- 5. PARAMETERS TABLE
CREATE TABLE IF NOT EXISTS public.parameters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pool_id UUID NOT NULL REFERENCES public.pools(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    point_value INTEGER NOT NULL DEFAULT 1 CHECK (point_value > 0),
    episode_number INTEGER,
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed', 'scored')),
    deadline TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

-- 6. VOTES TABLE
CREATE TABLE IF NOT EXISTS public.votes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    parameter_id UUID NOT NULL REFERENCES public.parameters(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    contestant_id UUID NOT NULL REFERENCES public.contestants(id) ON DELETE RESTRICT,
    submitted_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    UNIQUE (parameter_id, user_id)
);

-- 7. CORRECT ANSWERS TABLE
CREATE TABLE IF NOT EXISTS public.correct_answers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    parameter_id UUID NOT NULL UNIQUE REFERENCES public.parameters(id) ON DELETE CASCADE,
    contestant_id UUID NOT NULL REFERENCES public.contestants(id) ON DELETE RESTRICT,
    entered_by UUID NOT NULL REFERENCES public.users(id),
    entered_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

-- 8. POOL SCORES TABLE (Materialized for performance)
CREATE TABLE IF NOT EXISTS public.pool_scores (
    pool_id UUID NOT NULL REFERENCES public.pools(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    total_points INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    PRIMARY KEY (pool_id, user_id)
);

-- ============================================
-- STEP 2: ENABLE ROW LEVEL SECURITY
-- ============================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pools ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pool_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contestants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parameters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.correct_answers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pool_scores ENABLE ROW LEVEL SECURITY;

-- ============================================
-- STEP 2.5: CREATE HELPER FUNCTIONS (needed by policies)
-- ============================================

-- Helper function to check if pool has no members (bypasses RLS to avoid recursion)
CREATE OR REPLACE FUNCTION public.pool_has_no_members(pool_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN NOT EXISTS (
        SELECT 1 FROM public.pool_members
        WHERE pool_id = pool_uuid
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- STEP 3: CREATE RLS POLICIES
-- ============================================

-- Drop existing policies if they exist (for re-running migration)
DROP POLICY IF EXISTS "Users can read own profile" ON public.users;
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
DROP POLICY IF EXISTS "Users can read other profiles" ON public.users;
DROP POLICY IF EXISTS "Users can view pools they belong to" ON public.pools;
DROP POLICY IF EXISTS "Authenticated users can create pools" ON public.pools;
DROP POLICY IF EXISTS "Managers can update pools" ON public.pools;
DROP POLICY IF EXISTS "Users can view pool memberships" ON public.pool_members;
DROP POLICY IF EXISTS "Managers can add members" ON public.pool_members;
DROP POLICY IF EXISTS "Users can add themselves as manager" ON public.pool_members;
DROP POLICY IF EXISTS "Managers can update memberships" ON public.pool_members;
DROP POLICY IF EXISTS "Users can leave pools" ON public.pool_members;
DROP POLICY IF EXISTS "Users can view contestants in their pools" ON public.contestants;
DROP POLICY IF EXISTS "Managers can add contestants" ON public.contestants;
DROP POLICY IF EXISTS "Managers can update contestants" ON public.contestants;
DROP POLICY IF EXISTS "Managers can delete contestants" ON public.contestants;
DROP POLICY IF EXISTS "Users can view parameters in their pools" ON public.parameters;
DROP POLICY IF EXISTS "Managers can create parameters" ON public.parameters;
DROP POLICY IF EXISTS "Managers can update parameters" ON public.parameters;
DROP POLICY IF EXISTS "Managers can delete parameters" ON public.parameters;
DROP POLICY IF EXISTS "Users can view votes in their pools" ON public.votes;
DROP POLICY IF EXISTS "Users can submit votes for open parameters" ON public.votes;
DROP POLICY IF EXISTS "Users can update own votes" ON public.votes;
DROP POLICY IF EXISTS "Users can delete own votes" ON public.votes;
DROP POLICY IF EXISTS "Users can view correct answers in their pools" ON public.correct_answers;
DROP POLICY IF EXISTS "Managers can enter correct answers" ON public.correct_answers;
DROP POLICY IF EXISTS "Managers can update correct answers" ON public.correct_answers;
DROP POLICY IF EXISTS "Users can view scores in their pools" ON public.pool_scores;

-- Users table policies
CREATE POLICY "Users can read own profile"
    ON public.users
    FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
    ON public.users
    FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can read other profiles"
    ON public.users
    FOR SELECT
    USING (true);

-- Pools table policies
CREATE POLICY "Users can view pools they belong to"
    ON public.pools
    FOR SELECT
    USING (
        id IN (
            SELECT pool_id FROM public.pool_members
            WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Authenticated users can create pools"
    ON public.pools
    FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Managers can update pools"
    ON public.pools
    FOR UPDATE
    USING (
        id IN (
            SELECT pool_id FROM public.pool_members
            WHERE user_id = auth.uid() AND role = 'manager'
        )
    )
    WITH CHECK (
        id IN (
            SELECT pool_id FROM public.pool_members
            WHERE user_id = auth.uid() AND role = 'manager'
        )
    );

-- Pool members table policies
CREATE POLICY "Users can view pool memberships"
    ON public.pool_members
    FOR SELECT
    USING (
        pool_id IN (
            SELECT pool_id FROM public.pool_members
            WHERE user_id = auth.uid()
        )
    );

-- Allow users to add themselves as manager when creating a pool
-- This breaks the circular dependency where you need to be a manager to add members
CREATE POLICY "Users can add themselves as manager"
    ON public.pool_members
    FOR INSERT
    WITH CHECK (
        user_id = auth.uid() AND role = 'manager' AND
        -- Only allow if pool has no existing members (i.e., pool was just created)
        -- Use SECURITY DEFINER function to avoid RLS recursion
        public.pool_has_no_members(pool_id)
    );

-- Allow managers to add other members (not themselves)
CREATE POLICY "Managers can add members"
    ON public.pool_members
    FOR INSERT
    WITH CHECK (
        -- Only for adding other users (not yourself)
        user_id != auth.uid() AND
        pool_id IN (
            SELECT pool_id FROM public.pool_members
            WHERE user_id = auth.uid() AND role = 'manager'
        )
    );

CREATE POLICY "Managers can update memberships"
    ON public.pool_members
    FOR UPDATE
    USING (
        pool_id IN (
            SELECT pool_id FROM public.pool_members
            WHERE user_id = auth.uid() AND role = 'manager'
        )
    );

CREATE POLICY "Users can leave pools"
    ON public.pool_members
    FOR DELETE
    USING (
        user_id = auth.uid() AND
        (
            role = 'member' OR
            (
                role = 'manager' AND
                (SELECT COUNT(*) FROM public.pool_members WHERE pool_id = pool_members.pool_id AND role = 'manager') > 1
            )
        )
    );

-- Contestants table policies
CREATE POLICY "Users can view contestants in their pools"
    ON public.contestants
    FOR SELECT
    USING (
        pool_id IN (
            SELECT pool_id FROM public.pool_members
            WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Managers can add contestants"
    ON public.contestants
    FOR INSERT
    WITH CHECK (
        pool_id IN (
            SELECT pool_id FROM public.pool_members
            WHERE user_id = auth.uid() AND role = 'manager'
        )
    );

CREATE POLICY "Managers can update contestants"
    ON public.contestants
    FOR UPDATE
    USING (
        pool_id IN (
            SELECT pool_id FROM public.pool_members
            WHERE user_id = auth.uid() AND role = 'manager'
        )
    )
    WITH CHECK (
        pool_id IN (
            SELECT pool_id FROM public.pool_members
            WHERE user_id = auth.uid() AND role = 'manager'
        )
    );

CREATE POLICY "Managers can delete contestants"
    ON public.contestants
    FOR DELETE
    USING (
        pool_id IN (
            SELECT pool_id FROM public.pool_members
            WHERE user_id = auth.uid() AND role = 'manager'
        )
    );

-- Parameters table policies
CREATE POLICY "Users can view parameters in their pools"
    ON public.parameters
    FOR SELECT
    USING (
        pool_id IN (
            SELECT pool_id FROM public.pool_members
            WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Managers can create parameters"
    ON public.parameters
    FOR INSERT
    WITH CHECK (
        pool_id IN (
            SELECT pool_id FROM public.pool_members
            WHERE user_id = auth.uid() AND role = 'manager'
        )
    );

CREATE POLICY "Managers can update parameters"
    ON public.parameters
    FOR UPDATE
    USING (
        pool_id IN (
            SELECT pool_id FROM public.pool_members
            WHERE user_id = auth.uid() AND role = 'manager'
        )
    )
    WITH CHECK (
        pool_id IN (
            SELECT pool_id FROM public.pool_members
            WHERE user_id = auth.uid() AND role = 'manager'
        )
    );

CREATE POLICY "Managers can delete parameters"
    ON public.parameters
    FOR DELETE
    USING (
        pool_id IN (
            SELECT pool_id FROM public.pool_members
            WHERE user_id = auth.uid() AND role = 'manager'
        )
    );

-- Votes table policies
CREATE POLICY "Users can view votes in their pools"
    ON public.votes
    FOR SELECT
    USING (
        parameter_id IN (
            SELECT p.id FROM public.parameters p
            INNER JOIN public.pool_members pm ON p.pool_id = pm.pool_id
            WHERE pm.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can submit votes for open parameters"
    ON public.votes
    FOR INSERT
    WITH CHECK (
        user_id = auth.uid() AND
        parameter_id IN (
            SELECT id FROM public.parameters
            WHERE status = 'open' AND
            (deadline IS NULL OR deadline > now()) AND
            pool_id IN (
                SELECT pool_id FROM public.pool_members
                WHERE user_id = auth.uid()
            )
        )
    );

CREATE POLICY "Users can update own votes"
    ON public.votes
    FOR UPDATE
    USING (
        user_id = auth.uid() AND
        parameter_id IN (
            SELECT id FROM public.parameters
            WHERE status = 'open' AND
            (deadline IS NULL OR deadline > now())
        )
    )
    WITH CHECK (
        user_id = auth.uid() AND
        parameter_id IN (
            SELECT id FROM public.parameters
            WHERE status = 'open' AND
            (deadline IS NULL OR deadline > now())
        )
    );

CREATE POLICY "Users can delete own votes"
    ON public.votes
    FOR DELETE
    USING (
        user_id = auth.uid() AND
        parameter_id IN (
            SELECT id FROM public.parameters
            WHERE status = 'open' AND
            (deadline IS NULL OR deadline > now())
        )
    );

-- Correct answers table policies
CREATE POLICY "Users can view correct answers in their pools"
    ON public.correct_answers
    FOR SELECT
    USING (
        parameter_id IN (
            SELECT p.id FROM public.parameters p
            INNER JOIN public.pool_members pm ON p.pool_id = pm.pool_id
            WHERE pm.user_id = auth.uid()
        )
    );

CREATE POLICY "Managers can enter correct answers"
    ON public.correct_answers
    FOR INSERT
    WITH CHECK (
        entered_by = auth.uid() AND
        parameter_id IN (
            SELECT p.id FROM public.parameters p
            INNER JOIN public.pool_members pm ON p.pool_id = pm.pool_id
            WHERE pm.user_id = auth.uid() AND pm.role = 'manager' AND p.status = 'closed'
        ) AND
        EXISTS (
            SELECT 1 FROM public.votes
            WHERE parameter_id = correct_answers.parameter_id
        )
    );

CREATE POLICY "Managers can update correct answers"
    ON public.correct_answers
    FOR UPDATE
    USING (
        parameter_id IN (
            SELECT p.id FROM public.parameters p
            INNER JOIN public.pool_members pm ON p.pool_id = pm.pool_id
            WHERE pm.user_id = auth.uid() AND pm.role = 'manager'
        )
    );

-- Pool scores table policies
CREATE POLICY "Users can view scores in their pools"
    ON public.pool_scores
    FOR SELECT
    USING (
        pool_id IN (
            SELECT pool_id FROM public.pool_members
            WHERE user_id = auth.uid()
        )
    );

-- ============================================
-- STEP 4: CREATE FUNCTIONS AND TRIGGERS
-- ============================================

-- Function to automatically create user profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.users (id, email, display_name)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'display_name', NULL)
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create user profile on auth.users insert
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update users.updated_at
DROP TRIGGER IF EXISTS update_users_updated_at ON public.users;
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- Trigger to update pools.updated_at
DROP TRIGGER IF EXISTS update_pools_updated_at ON public.pools;
CREATE TRIGGER update_pools_updated_at
    BEFORE UPDATE ON public.pools
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- Trigger to update parameters.updated_at
DROP TRIGGER IF EXISTS update_parameters_updated_at ON public.parameters;
CREATE TRIGGER update_parameters_updated_at
    BEFORE UPDATE ON public.parameters
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- Function to automatically set parameter status to 'scored' when correct answer is entered
CREATE OR REPLACE FUNCTION public.set_parameter_scored()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.parameters
    SET status = 'scored'
    WHERE id = NEW.parameter_id AND status != 'scored';
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to set parameter status to 'scored'
DROP TRIGGER IF EXISTS set_parameter_scored_trigger ON public.correct_answers;
CREATE TRIGGER set_parameter_scored_trigger
    AFTER INSERT ON public.correct_answers
    FOR EACH ROW
    EXECUTE FUNCTION public.set_parameter_scored();

-- Function to update pool_scores when correct answers are entered
CREATE OR REPLACE FUNCTION public.update_pool_scores()
RETURNS TRIGGER AS $$
DECLARE
    pool_uuid UUID;
    param_point_value INTEGER;
BEGIN
    -- Get pool_id and point_value from the parameter
    SELECT p.pool_id, p.point_value INTO pool_uuid, param_point_value
    FROM public.parameters p
    WHERE p.id = NEW.parameter_id;

    -- Update scores for all users who voted correctly
    INSERT INTO public.pool_scores (pool_id, user_id, total_points, updated_at)
    SELECT 
        pool_uuid,
        v.user_id,
        param_point_value,
        now()
    FROM public.votes v
    WHERE v.parameter_id = NEW.parameter_id
      AND v.contestant_id = NEW.contestant_id
    ON CONFLICT (pool_id, user_id)
    DO UPDATE SET
        total_points = public.pool_scores.total_points + param_point_value,
        updated_at = now();

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to update pool_scores when correct answer is entered
DROP TRIGGER IF EXISTS update_pool_scores_trigger ON public.correct_answers;
CREATE TRIGGER update_pool_scores_trigger
    AFTER INSERT ON public.correct_answers
    FOR EACH ROW
    EXECUTE FUNCTION public.update_pool_scores();

-- Function to initialize pool_scores for all pool members when pool is created
CREATE OR REPLACE FUNCTION public.initialize_pool_scores()
RETURNS TRIGGER AS $$
BEGIN
    -- Initialize scores for all existing members
    INSERT INTO public.pool_scores (pool_id, user_id, total_points)
    SELECT NEW.id, user_id, 0
    FROM public.pool_members
    WHERE pool_id = NEW.id
    ON CONFLICT (pool_id, user_id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to initialize pool_scores when pool is created
DROP TRIGGER IF EXISTS initialize_pool_scores_trigger ON public.pools;
CREATE TRIGGER initialize_pool_scores_trigger
    AFTER INSERT ON public.pools
    FOR EACH ROW
    EXECUTE FUNCTION public.initialize_pool_scores();

-- Function to initialize pool_scores when user joins pool
CREATE OR REPLACE FUNCTION public.initialize_member_scores()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.pool_scores (pool_id, user_id, total_points)
    VALUES (NEW.pool_id, NEW.user_id, 0)
    ON CONFLICT (pool_id, user_id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to initialize pool_scores when user joins pool
DROP TRIGGER IF EXISTS initialize_member_scores_trigger ON public.pool_members;
CREATE TRIGGER initialize_member_scores_trigger
    AFTER INSERT ON public.pool_members
    FOR EACH ROW
    EXECUTE FUNCTION public.initialize_member_scores();

-- ============================================
-- STEP 5: CREATE INDEXES
-- ============================================

CREATE INDEX IF NOT EXISTS idx_pool_members_pool_id ON public.pool_members(pool_id);
CREATE INDEX IF NOT EXISTS idx_pool_members_user_id ON public.pool_members(user_id);
CREATE INDEX IF NOT EXISTS idx_pool_members_role ON public.pool_members(role);
CREATE INDEX IF NOT EXISTS idx_contestants_pool_id ON public.contestants(pool_id);
CREATE INDEX IF NOT EXISTS idx_contestants_eliminated_at ON public.contestants(eliminated_at);
CREATE INDEX IF NOT EXISTS idx_parameters_pool_id ON public.parameters(pool_id);
CREATE INDEX IF NOT EXISTS idx_parameters_status ON public.parameters(status);
CREATE INDEX IF NOT EXISTS idx_votes_parameter_id ON public.votes(parameter_id);
CREATE INDEX IF NOT EXISTS idx_votes_user_id ON public.votes(user_id);
CREATE INDEX IF NOT EXISTS idx_correct_answers_parameter_id ON public.correct_answers(parameter_id);
CREATE INDEX IF NOT EXISTS idx_pool_scores_pool_id ON public.pool_scores(pool_id);
CREATE INDEX IF NOT EXISTS idx_pool_scores_user_id ON public.pool_scores(user_id);

-- ============================================
-- COMPLETION MESSAGE
-- ============================================
DO $$
BEGIN
    RAISE NOTICE 'Database schema created successfully!';
    RAISE NOTICE 'All tables, RLS policies, triggers, and indexes have been set up.';
END $$;
