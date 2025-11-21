# Requirements Document: Online Pool Application

## 1. Project Overview

### 1.1 Purpose
Replace an existing manual pool tracking system (currently managed via Google Sheets) with a simple, dynamic, and fully hosted web application that supports user authentication and real-time data tracking for a small group of friends/family.

### 1.2 Objectives
- Enable multiple users to participate in pool competitions
- Provide real-time updates of pool standings
- Support role-based access control (managers vs. members)
- Maintain data integrity and security through Row Level Security (RLS)
- Deploy using free-tier services only

## 2. Technical Requirements

### 2.1 Technology Stack

| Component | Technology | Constraint | Justification |
|-----------|------------|------------|---------------|
| Hosting | Cloudflare Pages | Free Tier | Static site deployment, no server costs |
| Backend/DB | Supabase | Free Tier | Provides authentication and PostgreSQL database |
| Frontend | HTML, Tailwind CSS, Vanilla JavaScript | Single-file (index.html) | Simplifies deployment and maintenance |

### 2.2 Environment Configuration

**Required Environment Variables:**
- `SUPABASE_URL` - Supabase project URL
- `SUPABASE_ANON_KEY` - Supabase anonymous/public key

**Security Requirement:** Row Level Security (RLS) must be enabled on all database tables since the anon key will be exposed in client-side code.

### 2.3 Deployment Constraints
- Application must be deployable as a static site
- All frontend code must be contained in a single `index.html` file
- Must use CDN-hosted libraries (Tailwind CSS, Supabase JS client)
- No build process required

## 3. Functional Requirements

### 3.1 User Authentication (MVP)

**FR-1.1:** The system shall support user registration via email/password or magic link authentication using Supabase Auth.

**FR-1.2:** The system shall support user login via email/password or magic link authentication.

**FR-1.3:** The system shall maintain user sessions and persist authentication state across page refreshes.

**FR-1.4:** The system shall display the current authenticated user's email/display name.

**FR-1.5:** The system shall provide a logout function that clears the user session.

**FR-1.6:** All data interactions must be linked to an authenticated user via `auth.uid()`.

### 3.2 User Profile Management

**FR-2.1:** The system shall automatically create a user profile in the `users` table when a new user signs up.

**FR-2.2:** Users shall be able to view and update their own display name.

**FR-2.3:** User profiles shall include: id (UUID, linked to auth.users), email, display_name, created_at, updated_at.

### 3.3 Pool Management

**FR-3.1:** The system shall support creating pools with a name and optional description.

**FR-3.2:** Pool creators shall automatically be assigned the 'manager' role.

**FR-3.3:** Pools shall have a status field: 'active' or 'archived'.

**FR-3.4:** Managers shall be able to add members to pools.

**FR-3.5:** Users shall be able to view all pools they are members of (active and archived).

**FR-3.6:** Managers shall be able to update pool details and change pool status.

**FR-3.7:** Members shall be able to leave pools (unless they are the last manager).

### 3.4 Contestant Management

**FR-4.1:** Managers shall be able to add contestants to a pool.

**FR-4.2:** The system shall track contestant elimination status (eliminated_at timestamp).

**FR-4.3:** The system shall display active (non-eliminated) contestants for a pool.

**FR-4.4:** Managers shall be able to mark contestants as eliminated.

### 3.5 Parameter (Voting Question) Management

**FR-5.1:** Managers shall be able to create voting parameters/questions for a pool.

**FR-5.2:** Each parameter shall have:
- A question/name (text)
- A point value (integer > 0)
- An optional episode number
- A status: 'open', 'closed', or 'scored'
- An optional deadline timestamp

**FR-5.3:** Parameters in 'open' status shall accept votes from members.

**FR-5.4:** Managers shall be able to close parameters (change status to 'closed').

**FR-5.5:** Managers shall be able to enter correct answers for closed parameters.

**FR-5.6:** When a correct answer is entered, the parameter status shall automatically change to 'scored'.

### 3.6 Voting System

**FR-6.1:** Members shall be able to submit votes for parameters in 'open' status.

**FR-6.2:** Each member shall be allowed only one vote per parameter.

**FR-6.3:** Members shall be able to update their votes before the parameter deadline (if set) or before status changes to 'closed'.

**FR-6.4:** The system shall prevent vote submission after parameter deadline or when status is not 'open'.

**FR-6.5:** Votes shall link a user, parameter, and selected contestant.

### 3.7 Scoring and Standings

**FR-7.1:** The system shall calculate scores by comparing votes with correct answers.

**FR-7.2:** Points shall be awarded based on the parameter's point_value when a vote matches the correct answer.

**FR-7.3:** The system shall display standings showing all pool members ranked by total points.

**FR-7.4:** Standings shall update in real-time when scores change.

**FR-7.5:** The system shall display user display names and total points in the standings view.

### 3.8 Real-time Updates

**FR-8.1:** The system shall use Supabase Realtime to automatically update the UI when:
- Pool data changes
- Contestants are added/eliminated
- Parameters are created/updated
- Votes are submitted
- Correct answers are entered
- Scores are calculated

**FR-8.2:** The standings view shall update automatically without page refresh when scores change.

## 4. Data Model Requirements

### 4.1 Database Tables

#### 4.1.1 Users Table
- `id` (UUID, PRIMARY KEY, REFERENCES auth.users(id))
- `email` (TEXT, UNIQUE, NOT NULL)
- `display_name` (TEXT, nullable)
- `created_at` (TIMESTAMP, DEFAULT now())
- `updated_at` (TIMESTAMP, DEFAULT now())

#### 4.1.2 Pools Table
- `id` (UUID, PRIMARY KEY, DEFAULT uuid_generate_v4())
- `name` (TEXT, NOT NULL)
- `description` (TEXT, nullable)
- `status` (TEXT, NOT NULL, DEFAULT 'active', CHECK IN ('active', 'archived'))
- `created_at` (TIMESTAMP, DEFAULT now())
- `updated_at` (TIMESTAMP, DEFAULT now())

#### 4.1.3 Pool Members Table
- `id` (UUID, PRIMARY KEY, DEFAULT uuid_generate_v4())
- `pool_id` (UUID, NOT NULL, REFERENCES pools(id) ON DELETE CASCADE)
- `user_id` (UUID, NOT NULL, REFERENCES users(id) ON DELETE CASCADE)
- `role` (TEXT, NOT NULL, DEFAULT 'member', CHECK IN ('manager', 'member'))
- `joined_at` (TIMESTAMP, DEFAULT now())
- UNIQUE constraint on (`pool_id`, `user_id`)

#### 4.1.4 Contestants Table
- `id` (UUID, PRIMARY KEY, DEFAULT uuid_generate_v4())
- `pool_id` (UUID, NOT NULL, REFERENCES pools(id) ON DELETE CASCADE)
- `name` (TEXT, NOT NULL)
- `eliminated_at` (TIMESTAMP, nullable)
- `created_at` (TIMESTAMP, DEFAULT now())

#### 4.1.5 Parameters Table
- `id` (UUID, PRIMARY KEY, DEFAULT uuid_generate_v4())
- `pool_id` (UUID, NOT NULL, REFERENCES pools(id) ON DELETE CASCADE)
- `name` (TEXT, NOT NULL)
- `point_value` (INTEGER, NOT NULL, DEFAULT 1, CHECK > 0)
- `episode_number` (INTEGER, nullable)
- `status` (TEXT, NOT NULL, DEFAULT 'open', CHECK IN ('open', 'closed', 'scored'))
- `deadline` (TIMESTAMP, nullable)
- `created_at` (TIMESTAMP, DEFAULT now())
- `updated_at` (TIMESTAMP, DEFAULT now())

#### 4.1.6 Votes Table
- `id` (UUID, PRIMARY KEY, DEFAULT uuid_generate_v4())
- `parameter_id` (UUID, NOT NULL, REFERENCES parameters(id) ON DELETE CASCADE)
- `user_id` (UUID, NOT NULL, REFERENCES users(id) ON DELETE CASCADE)
- `contestant_id` (UUID, NOT NULL, REFERENCES contestants(id) ON DELETE RESTRICT)
- `submitted_at` (TIMESTAMP, DEFAULT now())
- UNIQUE constraint on (`parameter_id`, `user_id`)

#### 4.1.7 Correct Answers Table
- `id` (UUID, PRIMARY KEY, DEFAULT uuid_generate_v4())
- `parameter_id` (UUID, NOT NULL, UNIQUE, REFERENCES parameters(id) ON DELETE CASCADE)
- `contestant_id` (UUID, NOT NULL, REFERENCES contestants(id) ON DELETE RESTRICT)
- `entered_by` (UUID, NOT NULL, REFERENCES users(id))
- `entered_at` (TIMESTAMP, DEFAULT now())

### 4.2 Database Triggers

**TR-1:** Automatically create a user profile in the `users` table when a new user signs up via Supabase Auth.

**TR-2:** Update `updated_at` timestamp on `users` table when profile data changes.

**TR-3:** Update `updated_at` timestamp on `pools` table when pool data changes.

**TR-4:** Automatically set pool creator as manager when a new pool is created.

**TR-5:** Automatically set `parameters.status` to 'scored' when a correct answer is entered.

**TR-6:** Update `parameters.updated_at` when parameter data changes.

## 5. Security Requirements

### 5.1 Row Level Security (RLS)

**SEC-1:** RLS must be enabled on all database tables.

**SEC-2:** Users can read their own profile and update their own `display_name`.

**SEC-3:** Users can read other users' profiles for displaying standings.

**SEC-4:** Users can only view pools they are members of.

**SEC-5:** Only managers can update pool details or change pool status.

**SEC-6:** Only managers can add/edit/eliminate contestants.

**SEC-7:** Only managers can create/edit parameters and enter correct answers.

**SEC-8:** Members can only submit votes for parameters in 'open' status.

**SEC-9:** Members can only submit one vote per parameter.

**SEC-10:** Members can update their votes only before parameter deadline or before status changes to 'closed'.

**SEC-11:** Only managers can enter correct answers.

**SEC-12:** Prevent entering correct answers for parameters that don't have any votes.

### 5.2 Authentication

**SEC-13:** All database queries must use `auth.uid()` to ensure data is linked to authenticated users.

**SEC-14:** Unauthenticated users shall only see the login/signup interface.

## 6. User Interface Requirements

### 6.1 Layout and Design

**UI-1:** The application shall use Tailwind CSS for styling.

**UI-2:** The application shall be fully responsive and work on desktop, tablet, and mobile devices.

**UI-3:** The application shall have a clean, modern interface suitable for a small group of users.

### 6.2 Authentication UI

**UI-4:** The application shall display a login/signup form for unauthenticated users.

**UI-5:** The application shall display the current user's email/display name when authenticated.

**UI-6:** The application shall provide a logout button when authenticated.

### 6.3 Pool Management UI

**UI-7:** The application shall display a list of pools the user is a member of.

**UI-8:** The application shall provide a way to create new pools (for authenticated users).

**UI-9:** The application shall display pool details including name, description, and status.

**UI-10:** The application shall distinguish between active and archived pools.

### 6.4 Standings UI

**UI-11:** The application shall display standings in a clear, ranked list format.

**UI-12:** Standings shall show user display names and total points.

**UI-13:** Standings shall be sorted by total points (descending).

**UI-14:** Standings shall update automatically without page refresh.

### 6.5 Voting UI

**UI-15:** The application shall display open parameters for voting.

**UI-16:** The application shall allow members to select a contestant for each open parameter.

**UI-17:** The application shall display the user's existing votes.

**UI-18:** The application shall allow members to update their votes before deadlines.

## 7. Performance Requirements

**PERF-1:** The application shall load initial content within 2 seconds on a standard broadband connection.

**PERF-2:** Real-time updates shall appear within 1 second of data changes.

**PERF-3:** The application shall handle at least 50 concurrent users per pool.

## 8. Non-Functional Requirements

### 8.1 Deployment

**NFR-1:** The application shall be deployable to Cloudflare Pages without modification.

**NFR-2:** The application shall use only free-tier services.

**NFR-3:** The application shall not require a build process.

### 8.2 Maintainability

**NFR-4:** All frontend code shall be contained in a single `index.html` file.

**NFR-5:** Code shall be well-commented and organized for future maintenance.

### 8.3 Compatibility

**NFR-6:** The application shall work in modern browsers (Chrome, Firefox, Safari, Edge) released within the last 2 years.

## 9. MVP Scope (Initial Release)

The Minimum Viable Product shall include:

1. User authentication (sign up, sign in, sign out)
2. User profile creation and display
3. Pool creation and management (basic)
4. Contestant management (add, view, mark eliminated)
5. Parameter creation (basic)
6. Vote submission (basic)
7. Standings display (basic, calculated on-demand)
8. Real-time updates for standings

**Out of Scope for MVP:**
- Advanced pool management features
- Bulk operations
- Email notifications
- Advanced analytics
- Export functionality
- Mobile app

## 10. Future Enhancements

- Admin interface for manual score adjustments
- Email notifications for pool updates
- Pool invitation system
- Advanced analytics and statistics
- Export standings to CSV/PDF
- Mobile app (React Native or similar)
- Social features (comments, reactions)

