-- ============================================================================
-- LOCALLANCE MVP: COMPLETE DATABASE SCHEMA, SEED DATA, VIEWS & RLS POLICIES
-- ============================================================================

-- Enable UUID generation extension
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- 1. CATEGORIES TABLE & SEED DATA
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    slug TEXT UNIQUE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.categories (name, slug) VALUES
    ('Video Shoot & Reels Editing', 'video-editing'),
    ('Menu & Product Photography', 'photography-videography'),
    ('Social Commerce & Graphic Design', 'graphic-design'),
    ('Social Media Content Creation', 'social-media-content')
ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name;

-- ============================================================================
-- 2. SERVICE SKUs TABLE & OFFICIAL MVP SEED DATA
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.service_skus (
    code TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    category_slug TEXT NOT NULL REFERENCES public.categories(slug) ON DELETE RESTRICT,
    deliverable_spec TEXT NOT NULL,
    base_price_display TEXT NOT NULL,
    min_price_inr INTEGER NOT NULL CHECK (min_price_inr >= 0),
    turnaround_text TEXT NOT NULL,
    requires_onsite BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.service_skus (
    code, title, category_slug, deliverable_spec, base_price_display, min_price_inr, turnaround_text, requires_onsite
) VALUES
    (
        'SKU-VIDEO-01',
        'Vertical Video Shoot & Edit',
        'video-editing',
        '1-hour on-site filming, delivery of 2 finalized, fully-edited 30-second Reels/Shorts.',
        '₹1,499 – ₹2,499',
        1499,
        'On-site 1 hr + 24h edit',
        true
    ),
    (
        'SKU-PHOTO-02',
        'Menu & Product Photography',
        'photography-videography',
        'On-site setup shooting up to 15 optimized high-resolution item catalog shots.',
        '₹1,999',
        1999,
        'On-site shoot + 48h delivery',
        true
    ),
    (
        'SKU-BANNER-03',
        'Social Commerce Banner Design',
        'graphic-design',
        'Digital promotional graphic for online storefront sales, delivered in 24 hours.',
        '₹499 – ₹1,499',
        499,
        '24-hour digital delivery',
        false
    )
ON CONFLICT (code) DO UPDATE SET
    title = EXCLUDED.title,
    deliverable_spec = EXCLUDED.deliverable_spec,
    base_price_display = EXCLUDED.base_price_display,
    min_price_inr = EXCLUDED.min_price_inr,
    turnaround_text = EXCLUDED.turnaround_text,
    requires_onsite = EXCLUDED.requires_onsite;

-- ============================================================================
-- 3. PROFILES TABLE (Linked to Supabase auth.users for Admin/Role Management)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT,
    role TEXT NOT NULL DEFAULT 'freelancer' CHECK (role IN ('customer', 'freelancer', 'admin')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================================
-- 4. FREELANCERS TABLE (Cohort-20 Creators)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.freelancers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    full_name TEXT NOT NULL,
    slug TEXT UNIQUE NOT NULL,
    email TEXT NOT NULL,
    whatsapp_number TEXT NOT NULL,
    headline TEXT NOT NULL,
    bio TEXT NOT NULL,
    city_cluster TEXT NOT NULL,
    service_radius_km INTEGER NOT NULL DEFAULT 10 CHECK (service_radius_km >= 0),
    starting_price INTEGER NOT NULL CHECK (starting_price >= 0),
    category_slugs TEXT[] NOT NULL DEFAULT '{}',
    supported_sku_codes TEXT[] NOT NULL DEFAULT '{}',
    availability_slots TEXT NOT NULL DEFAULT 'Weekdays 2 PM – 7 PM & Weekends',
    portfolio_links TEXT[] NOT NULL DEFAULT '{}',
    approval_status TEXT NOT NULL DEFAULT 'pending' CHECK (approval_status IN ('pending', 'approved', 'rejected')),
    is_cohort_vetted BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================================
-- 5. ANTI-LEAKAGE PRIVACY VIEW: public_freelancers
-- Hides email & whatsapp_number from public frontend queries
-- ============================================================================
CREATE OR REPLACE VIEW public.public_freelancers AS
SELECT
    id,
    user_id,
    full_name,
    slug,
    headline,
    bio,
    city_cluster,
    service_radius_km,
    starting_price,
    category_slugs,
    supported_sku_codes,
    availability_slots,
    portfolio_links,
    approval_status,
    is_cohort_vetted,
    created_at
FROM public.freelancers
WHERE approval_status = 'approved';

-- Grant access to the view for anonymous and logged-in visitors
GRANT SELECT ON public.public_freelancers TO anon, authenticated;

-- ============================================================================
-- 6. PROJECT REQUESTS TABLE (Customer SKU Bookings & Custom Enquiries)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.project_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reference_code TEXT UNIQUE NOT NULL,
    customer_name TEXT NOT NULL,
    business_name TEXT,
    customer_whatsapp TEXT NOT NULL,
    city_cluster TEXT NOT NULL,
    shoot_address TEXT,
    sku_code TEXT NOT NULL DEFAULT 'CUSTOM-PROJECT',
    category_slug TEXT REFERENCES public.categories(slug) ON DELETE SET NULL,
    preferred_freelancer_slug TEXT,
    preferred_slot TEXT NOT NULL,
    budget_range TEXT NOT NULL,
    project_brief TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'new' CHECK (status IN ('new', 'matched', 'completed', 'cancelled')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================================
-- 7. MATCHES TABLE (Admin WhatsApp Dispatch & Escrow Proof Tracker)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID NOT NULL REFERENCES public.project_requests(id) ON DELETE CASCADE,
    freelancer_id UUID NOT NULL REFERENCES public.freelancers(id) ON DELETE CASCADE,
    agreed_amount_inr INTEGER NOT NULL CHECK (agreed_amount_inr >= 0),
    status TEXT NOT NULL DEFAULT 'proposed' CHECK (status IN ('proposed', 'accepted', 'proof_submitted', 'completed', 'cancelled')),
    proof_of_work_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================================
-- 8. HELPER FUNCTION FOR ADMIN VERIFICATION
-- ============================================================================
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.profiles
        WHERE id = auth.uid() AND role = 'admin'
    );
$$;

-- ============================================================================
-- 9. ENABLE ROW LEVEL SECURITY (RLS) ON ALL TABLES
-- ============================================================================
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_skus ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.freelancers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 10. RLS POLICIES (DROP IF EXISTS FOR IDEMPOTENCY, THEN CREATE)
-- ============================================================================

-- --- A. CATEGORIES POLICIES ---
DROP POLICY IF EXISTS "Public can view categories" ON public.categories;
CREATE POLICY "Public can view categories"
    ON public.categories FOR SELECT
    TO anon, authenticated
    USING (true);

DROP POLICY IF EXISTS "Admins have full access to categories" ON public.categories;
CREATE POLICY "Admins have full access to categories"
    ON public.categories FOR ALL
    TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- --- B. SERVICE SKUs POLICIES ---
DROP POLICY IF EXISTS "Public can view service_skus" ON public.service_skus;
CREATE POLICY "Public can view service_skus"
    ON public.service_skus FOR SELECT
    TO anon, authenticated
    USING (true);

DROP POLICY IF EXISTS "Admins have full access to service_skus" ON public.service_skus;
CREATE POLICY "Admins have full access to service_skus"
    ON public.service_skus FOR ALL
    TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- --- C. PROFILES POLICIES ---
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
CREATE POLICY "Users can view their own profile"
    ON public.profiles FOR SELECT
    TO authenticated
    USING (auth.uid() = id OR public.is_admin());

DROP POLICY IF EXISTS "Admins can manage all profiles" ON public.profiles;
CREATE POLICY "Admins can manage all profiles"
    ON public.profiles FOR ALL
    TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- --- D. FREELANCERS POLICIES ---
-- 1. Public can read approved rows ( enables public_freelancers view to work )
DROP POLICY IF EXISTS "Public can view approved freelancers" ON public.freelancers;
CREATE POLICY "Public can view approved freelancers"
    ON public.freelancers FOR SELECT
    TO anon, authenticated
    USING (approval_status = 'approved' OR public.is_admin());

-- 2. Public can apply via /join ONLY as 'pending' and unvetted (prevents self-approval hack)
DROP POLICY IF EXISTS "Public can submit pending freelancer application" ON public.freelancers;
CREATE POLICY "Public can submit pending freelancer application"
    ON public.freelancers FOR INSERT
    TO anon, authenticated
    WITH CHECK (
        approval_status = 'pending'
        AND is_cohort_vetted = false
    );

-- 3. Admins have full SELECT, UPDATE, DELETE on freelancers
DROP POLICY IF EXISTS "Admins can update freelancers" ON public.freelancers;
CREATE POLICY "Admins can update freelancers"
    ON public.freelancers FOR UPDATE
    TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins can delete freelancers" ON public.freelancers;
CREATE POLICY "Admins can delete freelancers"
    ON public.freelancers FOR DELETE
    TO authenticated
    USING (public.is_admin());

-- --- E. PROJECT REQUESTS POLICIES ---
-- 1. Customers can submit bookings ONLY with status = 'new'
DROP POLICY IF EXISTS "Public can submit new project requests" ON public.project_requests;
CREATE POLICY "Public can submit new project requests"
    ON public.project_requests FOR INSERT
    TO anon, authenticated
    WITH CHECK (status = 'new');

-- 2. Strictly Admins can view, update, or delete customer project requests
DROP POLICY IF EXISTS "Admins can view all project requests" ON public.project_requests;
CREATE POLICY "Admins can view all project requests"
    ON public.project_requests FOR SELECT
    TO authenticated
    USING (public.is_admin());

DROP POLICY IF EXISTS "Admins can update project requests" ON public.project_requests;
CREATE POLICY "Admins can update project requests"
    ON public.project_requests FOR UPDATE
    TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins can delete project requests" ON public.project_requests;
CREATE POLICY "Admins can delete project requests"
    ON public.project_requests FOR DELETE
    TO authenticated
    USING (public.is_admin());

-- --- F. MATCHES POLICIES ---
-- Strictly Admins can view, create, update, or delete dispatch matches
DROP POLICY IF EXISTS "Admins have full access to matches" ON public.matches;
CREATE POLICY "Admins have full access to matches"
    ON public.matches FOR ALL
    TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());